module Api
  module V1
    module Admin
      # GET /api/v1/admin/insights
      class InsightsController < BaseController
        def show
          @by_education = User.where.not(education_level: [nil, ''])
                               .group(:education_level)
                               .count

          @by_gender = User.group(:gender).count

          @by_occupation = User.where.not(occupation: [nil, ''])
                               .group(:occupation)
                               .count
                               .sort_by { |_, v| -v }
                               .first(10)
                               .to_h

          @by_interest = compute_interests

          # Dados demográficos geográficos: top 10 cidades por nº de usuários
          @top_cities = User.where.not(address: [nil, ''])
                            .group(Arel.sql("SPLIT_PART(address, ',', 1)"))
                            .count
                            .sort_by { |_, v| -v }
                            .first(10)
                            .to_h

          # Faixa etária
          @by_age_range = compute_age_ranges
        end

        private

        def compute_interests
          result = ActiveRecord::Base.connection.execute(<<~SQL)
            SELECT interest, COUNT(*) AS cnt
            FROM users,
                 jsonb_array_elements_text(
                   CASE
                     WHEN political_interests IS NULL                    THEN '[]'::jsonb
                     WHEN jsonb_typeof(political_interests) = 'array'   THEN political_interests
                     ELSE '[]'::jsonb
                   END
                 ) AS interest
            GROUP BY interest
            ORDER BY cnt DESC
            LIMIT 15
          SQL
          result.map { |r| [r['interest'], r['cnt'].to_i] }.to_h
        end

        def compute_age_ranges
          ranges = { '18-25' => 0, '26-35' => 0, '36-45' => 0, '46+' => 0 }
          User.where.not(birthdate: nil).pluck(:birthdate).each do |bd|
            age = ((Date.current - bd) / 365.25).floor
            bucket = case age
                     when 18..25 then '18-25'
                     when 26..35 then '26-35'
                     when 36..45 then '36-45'
                     else             '46+'
                     end
            ranges[bucket] += 1
          end
          ranges
        end
      end
    end
  end
end
