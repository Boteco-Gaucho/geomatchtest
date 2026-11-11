module Api
  module V1
    module Admin
      # GET /api/v1/admin/heatmap
      #   ?precision=2        (1–4, padrão 2 ≈ grade de 1.1 km)
      #   ?center_lat=&center_lng=&radius_km=   (filtro de raio Haversine)
      class HeatmapController < BaseController
        MAX_CLUSTERS = 1000

        def index
          precision = (params[:precision] || 2).to_i.clamp(1, 4)
          @clusters = build_clusters(precision)
          @total    = User.where.not(latitude: nil, longitude: nil).count
          @radius_applied = radius_filter? ? radius_params : nil
        end

        private

        def build_clusters(precision)
          scope = User.where.not(latitude: nil, longitude: nil)

          # Filtro de raio (Haversine via SQL nativo do Postgres)
          if radius_filter?
            clat, clng, radius = radius_params
            haversine_sql = ActiveRecord::Base.sanitize_sql_array([
              <<~SQL,
                6371.0 * acos(
                  LEAST(1.0,
                    cos(radians(?)) * cos(radians(latitude)) *
                    cos(radians(longitude) - radians(?)) +
                    sin(radians(?)) * sin(radians(latitude))
                  )
                ) <= ?
              SQL
              clat, clng, clat, radius
            ])
            scope = scope.where(haversine_sql)
          end

          scope
            .group(
              Arel.sql("ROUND(latitude::numeric,  #{precision})"),
              Arel.sql("ROUND(longitude::numeric, #{precision})")
            )
            .order(Arel.sql("COUNT(*) DESC"))
            .limit(MAX_CLUSTERS)
            .pluck(
              Arel.sql("ROUND(latitude::numeric,  #{precision})"),
              Arel.sql("ROUND(longitude::numeric, #{precision})"),
              Arel.sql("COUNT(*)")
            )
            .map { |lat, lng, count| { lat: lat.to_f, lng: lng.to_f, count: count.to_i } }
        end

        def radius_filter?
          params[:center_lat].present? &&
            params[:center_lng].present? &&
            params[:radius_km].present?
        end

        def radius_params
          [
            params[:center_lat].to_f,
            params[:center_lng].to_f,
            params[:radius_km].to_f.clamp(0.1, 5000.0)
          ]
        end
      end
    end
  end
end
