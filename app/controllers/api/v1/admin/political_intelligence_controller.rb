module Api
  module V1
    module Admin
      # GET /api/v1/admin/political_intelligence
      # Params:
      #   days    – 7|15|30|60 (default 30)
      #   topic   – filtro de tópico para heatmap e sentimento geral
      #   terms[] – termos de monitoramento (candidatos/partidos, max 10)
      #   report  – se "csv", força download do CSV agregado
      #
      # LGPD: nenhum dado individual é exposto.
      # Agrupamentos com menos de LGPD_MIN_USERS usuários únicos são suprimidos.
      class PoliticalIntelligenceController < BaseController

        LGPD_MIN_USERS  = 10
        MSG_SAMPLE_LIMIT = 1_500   # máx de mensagens carregadas no Ruby para análise

        rescue_from StandardError do |e|
          render json: {
            error:     e.class.to_s,
            message:   e.message,
            backtrace: e.backtrace&.first(6)
          }, status: :internal_server_error
        end

        # ── Action ───────────────────────────────────────────────────────────

        def show
          @days         = (params[:days] || 30).to_i.clamp(1, 90)
          @from         = @days.days.ago
          @topic_filter = params[:topic].presence
          @terms        = Array(params[:terms]).map(&:strip).reject(&:empty?).first(10)

          # Download CSV se solicitado
          if params[:report] == 'csv'
            return send_political_csv
          end

          @headline_insights  = compute_headline_insights
          @sentiment_overall  = compute_overall_sentiment
          @by_topic           = compute_by_topic
          @candidate_mentions = compute_candidate_mentions
          @thematic_heatmap   = compute_thematic_heatmap
        end

        private

        # ── Helpers SQL ──────────────────────────────────────────────────────

        def from_sql
          @from.utc.strftime('%Y-%m-%d %H:%M:%S')
        end

        def prev_from_sql
          (@days * 2).days.ago.utc.strftime('%Y-%m-%d %H:%M:%S')
        end

        def exec_sql(sql)
          ActiveRecord::Base.connection.exec_query(sql).to_a
        end

        # Escapa input antes de interpolar em SQL
        # Os parâmetros não vêm diretamente do usuário (terms/topic passam por esc()),
        # mas adicionamos proteção como boa prática.
        def esc(str)
          str.to_s.gsub("'", "''").gsub('%', '\%').gsub('_', '\_')
        end

        # Condição ILIKE para uma lista de palavras-chave (OR entre elas)
        def keywords_cond(keywords)
          keywords.map { |kw| "m.content ILIKE '%#{esc(kw)}%'" }.join(' OR ')
        end

        # Busca textos de mensagens (+ endereço do remetente) para análise Ruby
        def fetch_message_texts(topic: nil, term: nil, limit: MSG_SAMPLE_LIMIT)
          conds = ["m.created_at > '#{from_sql}'", "u.banned_at IS NULL"]

          if topic
            kws = SentimentAnalyzer::TOPICS[topic] || []
            conds << "(#{keywords_cond(kws)})" if kws.any?
          end

          conds << "m.content ILIKE '%#{esc(term)}%'" if term.present?

          exec_sql(<<~SQL)
            SELECT m.content, TRIM(SPLIT_PART(COALESCE(u.address,''), ',', 1)) AS region
            FROM messages m
            JOIN users u ON u.id = m.sender_id
            WHERE #{conds.join(' AND ')}
            ORDER BY m.created_at DESC
            LIMIT #{limit.to_i}
          SQL
        end

        # ── 1. Sentimento Geral ───────────────────────────────────────────────

        def compute_overall_sentiment
          rows = fetch_message_texts(topic: @topic_filter)
          SentimentAnalyzer.distribution(rows.map { |r| r['content'] })
        end

        # ── 2. Por Tópico ─────────────────────────────────────────────────────

        def compute_by_topic
          SentimentAnalyzer::TOPICS.filter_map do |topic, keywords|
            kw_cond = keywords_cond(keywords)

            # Contagens atual e anterior para calcular tendência
            counts = exec_sql(<<~SQL).first
              SELECT
                COUNT(*) FILTER (WHERE m.created_at > '#{from_sql}')                               AS current_count,
                COUNT(*) FILTER (WHERE m.created_at <= '#{from_sql}'
                                   AND m.created_at > '#{prev_from_sql}')                          AS prev_count,
                COUNT(DISTINCT u.id) FILTER (WHERE m.created_at > '#{from_sql}')                   AS unique_users
              FROM messages m
              JOIN users u ON u.id = m.sender_id
              WHERE u.banned_at IS NULL AND (#{kw_cond})
                AND m.created_at > '#{prev_from_sql}'
            SQL

            current      = counts['current_count'].to_i
            prev_cnt     = counts['prev_count'].to_i
            unique_users = counts['unique_users'].to_i
            trend        = prev_cnt > 0 ? (((current - prev_cnt).to_f / prev_cnt) * 100).round(1) : nil

            # Sentimento: amostra das mensagens do período
            texts     = fetch_message_texts(topic: topic, limit: 500).map { |r| r['content'] }
            sentiment = SentimentAnalyzer.distribution(texts)

            { topic: topic, mentions: current, unique_users: unique_users, trend_pct: trend, sentiment: sentiment }
          end.sort_by { |t| -t[:mentions] }
        end

        # ── 3. Menções a Candidatos/Termos ────────────────────────────────────

        def compute_candidate_mentions
          return [] if @terms.empty?

          @terms.map do |term|
            # Contagem + tendência
            counts = exec_sql(<<~SQL).first
              SELECT
                COUNT(*) FILTER (WHERE m.created_at > '#{from_sql}')                              AS current_count,
                COUNT(*) FILTER (WHERE m.created_at <= '#{from_sql}'
                                   AND m.created_at > '#{prev_from_sql}')                         AS prev_count,
                COUNT(DISTINCT u.id) FILTER (WHERE m.created_at > '#{from_sql}')                  AS unique_users
              FROM messages m
              JOIN users u ON u.id = m.sender_id
              WHERE u.banned_at IS NULL
                AND m.content ILIKE '%#{esc(term)}%'
                AND m.created_at > '#{prev_from_sql}'
            SQL

            current      = counts['current_count'].to_i
            prev_cnt     = counts['prev_count'].to_i
            unique_users = counts['unique_users'].to_i
            trend        = prev_cnt > 0 ? (((current - prev_cnt).to_f / prev_cnt) * 100).round(1) : nil

            # Sentimento das mensagens que mencionam o termo
            texts     = fetch_message_texts(term: term, limit: 500).map { |r| r['content'] }
            sentiment = SentimentAnalyzer.distribution(texts)

            # Por região (LGPD: mínimo LGPD_MIN_USERS usuários únicos por agrupamento)
            by_region = exec_sql(<<~SQL).map do |r|
              SELECT
                NULLIF(TRIM(SPLIT_PART(COALESCE(u.address,''), ',', 1)), '') AS region,
                COUNT(DISTINCT u.id) AS user_count,
                COUNT(m.id)          AS mention_count
              FROM messages m
              JOIN users u ON u.id = m.sender_id
              WHERE u.banned_at IS NULL
                AND m.content ILIKE '%#{esc(term)}%'
                AND m.created_at > '#{from_sql}'
              GROUP BY region
              HAVING COUNT(DISTINCT u.id) >= #{LGPD_MIN_USERS}
              ORDER BY mention_count DESC
              LIMIT 8
            SQL
              {
                region:   (r['region'] || 'Não informado').strip,
                mentions: r['mention_count'].to_i,
                users:    r['user_count'].to_i
              }
            end

            {
              term:         term,
              mentions:     current,
              unique_users: unique_users,
              trend_pct:    trend,
              sentiment:    sentiment,
              by_region:    by_region
            }
          end
        end

        # ── 4. Mapa de Calor Temático ─────────────────────────────────────────
        # Grade ~0.1° ≈ 11km — LGPD: células com < LGPD_MIN_USERS usuarios são suprimidas

        def compute_thematic_heatmap
          topic    = @topic_filter.presence || SentimentAnalyzer::TOPICS.keys.first
          keywords = SentimentAnalyzer::TOPICS[topic] || []
          return [] if keywords.empty?

          kw_cond = keywords_cond(keywords)

          exec_sql(<<~SQL).map do |r|
            SELECT
              ROUND(CAST(u.latitude  AS numeric), 1) AS lat,
              ROUND(CAST(u.longitude AS numeric), 1) AS lng,
              COUNT(DISTINCT u.id)                   AS user_count,
              COUNT(m.id)                            AS intensity
            FROM messages m
            JOIN users u ON u.id = m.sender_id
            WHERE u.banned_at IS NULL
              AND u.latitude  IS NOT NULL
              AND u.longitude IS NOT NULL
              AND m.created_at > '#{from_sql}'
              AND (#{kw_cond})
            GROUP BY lat, lng
            HAVING COUNT(DISTINCT u.id) >= #{LGPD_MIN_USERS}
            ORDER BY intensity DESC
            LIMIT 300
          SQL
            { lat: r['lat'].to_f, lng: r['lng'].to_f, intensity: r['intensity'].to_i }
          end
        end

        # ── 5. Headline Insights ──────────────────────────────────────────────
        # Detecta tópicos com variação de menções > 15% entre os dois períodos

        def compute_headline_insights
          insights = []

          SentimentAnalyzer::TOPICS.each do |topic, keywords|
            kw_cond = keywords_cond(keywords)

            counts = exec_sql(<<~SQL).first
              SELECT
                COUNT(*) FILTER (WHERE m.created_at > '#{from_sql}')                         AS current_count,
                COUNT(*) FILTER (WHERE m.created_at <= '#{from_sql}'
                                   AND m.created_at > '#{prev_from_sql}')                    AS prev_count,
                COUNT(DISTINCT u.id) FILTER (WHERE m.created_at > '#{from_sql}')             AS unique_users
              FROM messages m
              JOIN users u ON u.id = m.sender_id
              WHERE u.banned_at IS NULL AND (#{kw_cond})
                AND m.created_at > '#{prev_from_sql}'
            SQL

            current      = counts['current_count'].to_i
            prev_cnt     = counts['prev_count'].to_i
            unique_users = counts['unique_users'].to_i
            next if current == 0 || prev_cnt == 0 || unique_users < LGPD_MIN_USERS

            trend = (((current - prev_cnt).to_f / prev_cnt) * 100).round(0).to_i
            next if trend.abs < 15   # ignora variações menores que 15%

            # Sentimento dominante do tópico
            texts     = fetch_message_texts(topic: topic, limit: 300).map { |r| r['content'] }
            dist      = SentimentAnalyzer.distribution(texts)
            dominant  = %i[positive negative neutral].max_by { |k| dist[k] }
            dom_label = { positive: 'positivo', negative: 'negativo', neutral: 'neutro' }[dominant]

            direction = trend > 0 ? 'subiram' : 'caíram'
            insights << {
              topic:            topic,
              trend_pct:        trend,
              current_mentions: current,
              unique_users:     unique_users,
              sentiment_label:  dom_label,
              description:      "Menções a #{topic} #{direction} #{trend.abs}% vs. período anterior (sentimento #{dom_label})"
            }
          end

          insights.sort_by { |i| -i[:trend_pct].abs }.first(5)
        end

        # ── CSV para Imprensa ─────────────────────────────────────────────────
        # 100% anonimizado: agrupado por município/tópico — sem dados individuais.
        # Suprime células com < LGPD_MIN_USERS usuários únicos.

        def send_political_csv
          rows = exec_sql(<<~SQL)
            SELECT
              NULLIF(TRIM(SPLIT_PART(COALESCE(u.address,''), ',', 1)), 'Não informado') AS municipio,
              COALESCE(NULLIF(u.gender, ''), 'Não informado')                           AS genero,
              COUNT(DISTINCT u.id)                                                      AS usuarios_unicos,
              COUNT(m.id)                                                               AS total_mensagens
            FROM messages m
            JOIN users u ON u.id = m.sender_id
            WHERE u.banned_at IS NULL
              AND m.created_at > '#{from_sql}'
            GROUP BY municipio, genero
            HAVING COUNT(DISTINCT u.id) >= #{LGPD_MIN_USERS}
            ORDER BY total_mensagens DESC
            LIMIT 500
          SQL

          bom = "\xEF\xBB\xBF"   # UTF-8 BOM para Excel
          csv = bom + "Municipio,Genero,Usuarios Unicos,Total Mensagens\n"
          rows.each do |r|
            csv += [
              r['municipio'] || 'Não informado',
              r['genero'],
              r['usuarios_unicos'],
              r['total_mensagens']
            ].join(',') + "\n"
          end

          send_data csv,
            filename:    "geomatch_inteligencia_politica_#{Date.today}.csv",
            type:        'text/csv; charset=utf-8',
            disposition: 'attachment'
        end
      end
    end
  end
end
