module Api
  module V1
    module Admin
      # GET /api/v1/admin/bi_export
      # Retorna CSV com dados agregados e anonimizados.
      # NENHUM dado pessoal (nome, e-mail, telefone) é incluído.
      class BiExportController < BaseController
        def show
          rows = generate_rows

          csv = build_csv(rows)

          send_data "\xEF\xBB\xBF#{csv}",
                    filename:    "geomatch_bi_#{Date.current}.csv",
                    type:        'text/csv; charset=utf-8',
                    disposition: 'attachment'
        end

        private

        def generate_rows
          ActiveRecord::Base.connection.execute(<<~SQL).to_a
            SELECT
              COALESCE(NULLIF(TRIM(SPLIT_PART(u.address, ',', 1)), ''), 'Não informado') AS cidade,
              CASE
                WHEN EXTRACT(YEAR FROM AGE(u.birthdate)) BETWEEN 18 AND 25 THEN '18-25'
                WHEN EXTRACT(YEAR FROM AGE(u.birthdate)) BETWEEN 26 AND 35 THEN '26-35'
                WHEN EXTRACT(YEAR FROM AGE(u.birthdate)) BETWEEN 36 AND 45 THEN '36-45'
                WHEN EXTRACT(YEAR FROM AGE(u.birthdate)) > 45              THEN '46+'
                ELSE 'Não informado'
              END AS faixa_etaria,
              COALESCE(NULLIF(u.gender, ''), 'Não informado')          AS genero,
              COALESCE(NULLIF(u.education_level, ''), 'Não informado') AS escolaridade,
              COALESCE(
                NULLIF(TRIM(SPLIT_PART(u.hobbies, ',', 1)), ''),
                'Não informado'
              )                                                          AS interesse_principal,
              COUNT(DISTINCT u.id)                                       AS qtd_usuarios,
              COALESCE(SUM(mc.msg_count), 0)                            AS vol_mensagens
            FROM users u
            LEFT JOIN (
              SELECT
                CASE
                  WHEN m.user_id         = msg.sender_id THEN m.user_id
                  ELSE m.matched_user_id
                END AS user_id,
                COUNT(*) AS msg_count
              FROM messages msg
              JOIN matches m ON msg.match_id = m.id
              GROUP BY 1
            ) mc ON mc.user_id = u.id
            WHERE u.birthdate IS NOT NULL
              AND u.banned_at IS NULL
            GROUP BY cidade, faixa_etaria, genero, escolaridade, interesse_principal
            ORDER BY vol_mensagens DESC
            LIMIT 5000
          SQL
        end

        def build_csv(rows)
          headers = %w[Cidade Faixa_Etária Gênero Escolaridade Interesse_Principal Qtd_Usuários Vol_Mensagens]
          lines   = [headers.join(',')]
          rows.each do |r|
            lines << [
              csv_cell(r['cidade']),
              csv_cell(r['faixa_etaria']),
              csv_cell(r['genero']),
              csv_cell(r['escolaridade']),
              csv_cell(r['interesse_principal']),
              r['qtd_usuarios'],
              r['vol_mensagens']
            ].join(',')
          end
          lines.join("\n")
        end

        def csv_cell(val)
          "\"#{val.to_s.gsub('"', '""')}\""
        end
      end
    end
  end
end
