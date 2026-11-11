module Api
  module V1
    module Admin
      # GET /api/v1/admin/engagement
      # Params: days (7|15|30, default 30), city, state
      #
      # Detecta o adapter automaticamente:
      #   – PostgreSQL (Render): queries com LATERAL JOIN, EXTRACT+EPOCH, AT TIME ZONE, ILIKE
      #   – SQLite (dev local):  queries equivalentes com strftime, JULIANDAY e LIKE
      class EngagementController < BaseController

        # Captura QUALQUER erro — inclusive erros de renderização Jbuilder
        # que escapam do rescue local dentro do action.
        rescue_from StandardError do |e|
          render json: {
            error:     e.class.to_s,
            message:   e.message,
            backtrace: e.backtrace&.first(8),
            adapter:   (ActiveRecord::Base.connection.adapter_name.downcase rescue 'unknown')
          }, status: :internal_server_error
        end

        def show
          return unless admin_authorized?
          @days  = (params[:days] || 30).to_i.clamp(1, 90)
          @from  = @days.days.ago
          @city  = params[:city].presence
          @state = params[:state].presence

          @kpis          = global_kpis
          @by_gender     = engagement_by_gender
          @swipe_stats   = swipe_stats_by_gender
          @response_time = avg_response_time_by_gender
          @by_shift      = usage_by_shift
          @top_rankings  = top_rankings
        rescue => e
          render json: {
            error:     e.class.to_s,
            message:   e.message,
            backtrace: e.backtrace&.first(5),
            adapter:   adapter_name
          }, status: :internal_server_error
        end

        private

        # Retorna false e renderiza 403 se o usuário não for admin.
        # Evita rodar queries pesadas antes de verificar permissão.
        def admin_authorized?
          return true if current_api_user&.admin?
          render json: { error: 'Acesso negado.', detail: 'Requer admin.' }, status: :forbidden
          false
        end

        # ── Detecção de Adapter ───────────────────────────────────────

        def sqlite?
          adapter_name.include?('sqlite')
        end

        def adapter_name
          ActiveRecord::Base.connection.adapter_name.downcase
        end

        # ── Helpers de Query ─────────────────────────────────────────

        # Timestamp derivado de dados internos — seguro para interpolação
        def from_sql
          @from.utc.strftime('%Y-%m-%d %H:%M:%S')
        end

        # ILIKE (PG) vs LIKE (SQLite — já é case-insensitive para ASCII)
        def like_op
          sqlite? ? 'LIKE' : 'ILIKE'
        end

        def location_conditions
          conds = []
          conds << "users.address #{like_op} '%%#{esc_sql(@city)}%%'"  if @city
          conds << "users.address #{like_op} '%%#{esc_sql(@state)}%%'" if @state
          conds.empty? ? '1=1' : conds.join(' AND ')
        end

        # Escapa aspas simples — valor não vem do usuário direto, mas por precaução
        def esc_sql(str)
          str.to_s.gsub("'", "''")
        end

        def exec_sql(sql)
          ActiveRecord::Base.connection.exec_query(sql).to_a
        end

        # ── KPIs Globais ─────────────────────────────────────────────
        # ActiveRecord puro — funciona em ambos os adapters

        def global_kpis
          total_users   = User.where(banned_at: nil).count
          active_users  = User.where(banned_at: nil).where('last_seen_at > ?', @from).count
          total_likes   = Like.where('created_at > ?', @from).count
          total_matches = Match.where('created_at > ?', @from).count
          total_msgs    = Message.where('created_at > ?', @from).count
          match_rate    = total_likes > 0 ? ((total_matches * 2.0 / total_likes) * 100).round(1) : 0.0

          {
            total_users:    total_users,
            active_users:   active_users,
            match_rate:     match_rate,
            total_likes:    total_likes,
            total_matches:  total_matches,
            total_messages: total_msgs,
            period_days:    @days
          }
        end

        # ── Engajamento por Gênero ────────────────────────────────────
        # Compatível com ambos — apenas location_conditions usa like_op

        def engagement_by_gender
          rows = exec_sql(<<~SQL)
            SELECT
              COALESCE(NULLIF(u.gender, ''), 'Não informado') AS gender,
              COUNT(DISTINCT u.id)             AS active_users,
              COALESCE(SUM(msgs.msg_count), 0) AS messages_sent,
              COALESCE(SUM(lks.like_count), 0) AS likes_given
            FROM users u
            LEFT JOIN (
              SELECT sender_id, COUNT(*) AS msg_count
              FROM messages
              WHERE created_at > '#{from_sql}'
              GROUP BY sender_id
            ) msgs ON msgs.sender_id = u.id
            LEFT JOIN (
              SELECT liker_id, COUNT(*) AS like_count
              FROM likes
              WHERE created_at > '#{from_sql}'
              GROUP BY liker_id
            ) lks ON lks.liker_id = u.id
            WHERE u.banned_at IS NULL
              AND u.last_seen_at > '#{from_sql}'
              AND #{location_conditions}
            GROUP BY gender
            ORDER BY active_users DESC
          SQL

          total = rows.sum { |r| r['active_users'].to_i }.to_f
          rows.map do |r|
            users = r['active_users'].to_i
            {
              gender:        r['gender'],
              active_users:  users,
              share_pct:     total > 0 ? ((users / total) * 100).round(1) : 0.0,
              messages_sent: r['messages_sent'].to_i,
              likes_given:   r['likes_given'].to_i
            }
          end
        end

        # ── Métricas de Swipes ────────────────────────────────────────
        # Compatível com ambos

        def swipe_stats_by_gender
          rows = exec_sql(<<~SQL)
            SELECT
              COALESCE(NULLIF(u.gender, ''), 'Não informado') AS gender,
              COUNT(DISTINCT lg.id) AS likes_given,
              COUNT(DISTINCT lr.id) AS likes_received,
              COUNT(DISTINCT m.id)  AS matches_created
            FROM users u
            LEFT JOIN likes lg ON lg.liker_id = u.id AND lg.created_at > '#{from_sql}'
            LEFT JOIN likes lr ON lr.liked_id  = u.id AND lr.created_at > '#{from_sql}'
            LEFT JOIN matches m ON (m.user_id = u.id OR m.matched_user_id = u.id)
              AND m.created_at > '#{from_sql}'
            WHERE u.banned_at IS NULL
              AND #{location_conditions}
            GROUP BY gender
            ORDER BY likes_given DESC
          SQL

          rows.map do |r|
            given   = r['likes_given'].to_i
            matched = r['matches_created'].to_i
            {
              gender:         r['gender'],
              likes_given:    given,
              likes_received: r['likes_received'].to_i,
              matches:        matched,
              match_rate:     given > 0 ? ((matched.to_f / given) * 100).round(1) : 0.0
            }
          end
        end

        # ── Velocidade de Resposta ────────────────────────────────────
        # PG:     LATERAL JOIN + EXTRACT(EPOCH) — pega apenas a 1ª resposta
        # SQLite: self-join simples (menos preciso, suficiente para dev)

        def avg_response_time_by_gender
          rows = sqlite? ? response_time_sqlite : response_time_pg
          rows.map do |r|
            mins = r['avg_minutes'].to_f
            {
              gender:         r['gender'],
              response_count: r['response_count'].to_i,
              avg_minutes:    mins,
              avg_formatted:  format_minutes(mins)
            }
          end
        end

        def response_time_pg
          exec_sql(<<~SQL)
            SELECT
              COALESCE(NULLIF(u.gender, ''), 'Não informado') AS gender,
              COUNT(*) AS response_count,
              ROUND(
                AVG(EXTRACT(EPOCH FROM (reply.created_at - orig.created_at)) / 60)::numeric,
              1) AS avg_minutes
            FROM messages orig
            JOIN LATERAL (
              SELECT m2.created_at, m2.sender_id
              FROM   messages m2
              WHERE  m2.match_id   = orig.match_id
                AND  m2.sender_id != orig.sender_id
                AND  m2.created_at > orig.created_at
                AND  m2.created_at < orig.created_at + INTERVAL '24 hours'
              ORDER BY m2.created_at
              LIMIT 1
            ) reply ON TRUE
            JOIN users u ON u.id = reply.sender_id
            WHERE orig.created_at > '#{from_sql}'
              AND u.banned_at IS NULL
              AND #{location_conditions}
            GROUP BY gender
            ORDER BY avg_minutes
          SQL
        end

        def response_time_sqlite
          exec_sql(<<~SQL)
            SELECT
              COALESCE(NULLIF(u.gender, ''), 'Não informado') AS gender,
              COUNT(*) AS response_count,
              ROUND(AVG((JULIANDAY(m2.created_at) - JULIANDAY(m1.created_at)) * 1440), 1) AS avg_minutes
            FROM messages m1
            JOIN messages m2
              ON  m2.match_id   = m1.match_id
              AND m2.sender_id != m1.sender_id
              AND m2.created_at > m1.created_at
              AND datetime(m2.created_at) < datetime(m1.created_at, '+24 hours')
            JOIN users u ON u.id = m2.sender_id
            WHERE m1.created_at > '#{from_sql}'
              AND u.banned_at IS NULL
              AND #{location_conditions}
            GROUP BY gender
            ORDER BY avg_minutes
          SQL
        end

        # ── Uso por Turno ─────────────────────────────────────────────
        # PG:     EXTRACT(HOUR … AT TIME ZONE 'America/Sao_Paulo')
        # SQLite: strftime('%H', …) — UTC (sem conversão de fuso)

        def usage_by_shift
          rows = sqlite? ? shift_sqlite : shift_pg
          rows.map { |r| { shift: r['shift'], messages: r['messages'].to_i, active_users: r['active_users'].to_i } }
        end

        def shift_pg
          exec_sql(<<~SQL)
            SELECT
              CASE
                WHEN EXTRACT(HOUR FROM messages.created_at AT TIME ZONE 'America/Sao_Paulo') BETWEEN 6  AND 11 THEN 'Manhã'
                WHEN EXTRACT(HOUR FROM messages.created_at AT TIME ZONE 'America/Sao_Paulo') BETWEEN 12 AND 17 THEN 'Tarde'
                WHEN EXTRACT(HOUR FROM messages.created_at AT TIME ZONE 'America/Sao_Paulo') BETWEEN 18 AND 22 THEN 'Noite'
                ELSE 'Madrugada'
              END AS shift,
              COUNT(*) AS messages,
              COUNT(DISTINCT messages.sender_id) AS active_users
            FROM messages
            JOIN users ON users.id = messages.sender_id
            WHERE messages.created_at > '#{from_sql}'
              AND users.banned_at IS NULL
              AND #{location_conditions}
            GROUP BY shift
            ORDER BY messages DESC
          SQL
        end

        def shift_sqlite
          exec_sql(<<~SQL)
            SELECT
              CASE
                WHEN CAST(strftime('%H', messages.created_at) AS INTEGER) BETWEEN 6  AND 11 THEN 'Manhã'
                WHEN CAST(strftime('%H', messages.created_at) AS INTEGER) BETWEEN 12 AND 17 THEN 'Tarde'
                WHEN CAST(strftime('%H', messages.created_at) AS INTEGER) BETWEEN 18 AND 22 THEN 'Noite'
                ELSE 'Madrugada'
              END AS shift,
              COUNT(*) AS messages,
              COUNT(DISTINCT messages.sender_id) AS active_users
            FROM messages
            JOIN users ON users.id = messages.sender_id
            WHERE messages.created_at > '#{from_sql}'
              AND users.banned_at IS NULL
              AND #{location_conditions}
            GROUP BY shift
            ORDER BY messages DESC
          SQL
        end

        # ── Top Rankings ─────────────────────────────────────────────

        def top_rankings
          {
            top_engaged:    top_engaged_users,
            top_liked:      top_liked_users,
            top_liking:     top_liking_users,
            top_responders: top_responder_users
          }
        end

        # Compatível com ambos
        def top_engaged_users
          exec_sql(<<~SQL).map { |r| map_ranking_row(r) }
            SELECT
              u.id, u.username,
              COALESCE(NULLIF(u.gender, ''), '?') AS gender,
              COALESCE(p.name, 'Free') AS plan_name,
              (COALESCE(msg_c.cnt, 0) + COALESCE(like_c.cnt, 0)) AS score,
              COALESCE(msg_c.cnt, 0)  AS messages_sent,
              COALESCE(like_c.cnt, 0) AS likes_given
            FROM users u
            LEFT JOIN plans p ON p.id = u.plan_id
            LEFT JOIN (SELECT sender_id, COUNT(*) AS cnt FROM messages WHERE created_at > '#{from_sql}' GROUP BY sender_id) msg_c  ON msg_c.sender_id  = u.id
            LEFT JOIN (SELECT liker_id,  COUNT(*) AS cnt FROM likes    WHERE created_at > '#{from_sql}' GROUP BY liker_id)  like_c ON like_c.liker_id = u.id
            WHERE u.banned_at IS NULL AND #{location_conditions}
            ORDER BY score DESC
            LIMIT 10
          SQL
        end

        def top_liked_users
          exec_sql(<<~SQL).map { |r| map_ranking_row(r) }
            SELECT u.id, u.username,
              COALESCE(NULLIF(u.gender, ''), '?') AS gender,
              COALESCE(p.name, 'Free') AS plan_name,
              COUNT(l.id) AS score
            FROM users u
            LEFT JOIN plans p ON p.id = u.plan_id
            JOIN likes l ON l.liked_id = u.id AND l.created_at > '#{from_sql}'
            WHERE u.banned_at IS NULL AND #{location_conditions}
            GROUP BY u.id, u.username, gender, plan_name
            ORDER BY score DESC
            LIMIT 10
          SQL
        end

        def top_liking_users
          exec_sql(<<~SQL).map { |r| map_ranking_row(r) }
            SELECT u.id, u.username,
              COALESCE(NULLIF(u.gender, ''), '?') AS gender,
              COALESCE(p.name, 'Free') AS plan_name,
              COUNT(l.id) AS score
            FROM users u
            LEFT JOIN plans p ON p.id = u.plan_id
            JOIN likes l ON l.liker_id = u.id AND l.created_at > '#{from_sql}'
            WHERE u.banned_at IS NULL AND #{location_conditions}
            GROUP BY u.id, u.username, gender, plan_name
            ORDER BY score DESC
            LIMIT 10
          SQL
        end

        # Top responders: PG usa LATERAL; SQLite usa self-join
        def top_responder_users
          sqlite? ? top_responders_sqlite : top_responders_pg
        end

        def top_responders_pg
          exec_sql(<<~SQL).map { |r| map_ranking_row(r) }
            SELECT u.id, u.username,
              COALESCE(NULLIF(u.gender, ''), '?') AS gender,
              COALESCE(p.name, 'Free') AS plan_name,
              ROUND(AVG(EXTRACT(EPOCH FROM (reply.created_at - orig.created_at)) / 60)::numeric, 1) AS score,
              COUNT(*) AS response_count
            FROM messages orig
            JOIN LATERAL (
              SELECT m2.created_at, m2.sender_id
              FROM   messages m2
              WHERE  m2.match_id   = orig.match_id
                AND  m2.sender_id != orig.sender_id
                AND  m2.created_at > orig.created_at
                AND  m2.created_at < orig.created_at + INTERVAL '24 hours'
              ORDER BY m2.created_at LIMIT 1
            ) reply ON TRUE
            JOIN users u ON u.id = reply.sender_id
            LEFT JOIN plans p ON p.id = u.plan_id
            WHERE orig.created_at > '#{from_sql}'
              AND u.banned_at IS NULL AND #{location_conditions}
            GROUP BY u.id, u.username, gender, plan_name
            HAVING COUNT(*) >= 3
            ORDER BY score ASC
            LIMIT 10
          SQL
        end

        def top_responders_sqlite
          exec_sql(<<~SQL).map { |r| map_ranking_row(r) }
            SELECT u.id, u.username,
              COALESCE(NULLIF(u.gender, ''), '?') AS gender,
              COALESCE(p.name, 'Free') AS plan_name,
              ROUND(AVG((JULIANDAY(m2.created_at) - JULIANDAY(m1.created_at)) * 1440), 1) AS score,
              COUNT(*) AS response_count
            FROM messages m1
            JOIN messages m2
              ON  m2.match_id   = m1.match_id
              AND m2.sender_id != m1.sender_id
              AND m2.created_at > m1.created_at
              AND datetime(m2.created_at) < datetime(m1.created_at, '+24 hours')
            JOIN users u ON u.id = m2.sender_id
            LEFT JOIN plans p ON p.id = u.plan_id
            WHERE m1.created_at > '#{from_sql}'
              AND u.banned_at IS NULL AND #{location_conditions}
            GROUP BY u.id, u.username, gender, plan_name
            HAVING COUNT(*) >= 3
            ORDER BY score ASC
            LIMIT 10
          SQL
        end

        def map_ranking_row(r)
          {
            id:       r['id'],
            username: r['username'] || "Usuário ##{r['id']}",
            gender:   r['gender'],
            plan:     r['plan_name'],
            score:    r['score'].to_f,
            extra:    r.slice('messages_sent', 'likes_given', 'response_count')
                       .transform_values(&:to_i)
                       .reject { |_, v| v == 0 }
          }
        end

        def format_minutes(mins)
          return '—' if mins <= 0
          return "#{mins.round(1)} min" if mins < 60
          h = (mins / 60).floor
          m = (mins % 60).round
          "#{h}h#{m > 0 ? " #{m}min" : ''}"
        end
      end
    end
  end
end
