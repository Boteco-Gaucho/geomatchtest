module Api
  module V1
    module Admin
      # GET /api/v1/admin/live_map
      # JSON leve: sem nomes ou fotos para o mapa carregar rápido.
      # Suporta filtros demográficos: gender, age_range, city, state, country
      class LiveMapController < BaseController
        def index
          @users = User
            .where.not(latitude: nil, longitude: nil)
            .select(:id, :latitude, :longitude, :last_seen_at, :invisible, :banned_at, :gender, :birthdate, :address)

          # Filtros demográficos opcionais
          @users = @users.where(gender: params[:gender])                    if params[:gender].present?
          @users = @users.where('address ILIKE ?', "%#{params[:city]}%")    if params[:city].present?
          @users = @users.where('address ILIKE ?', "%#{params[:state]}%")   if params[:state].present?
          @users = @users.where('address ILIKE ?', "%#{params[:country]}%") if params[:country].present?
          @users = apply_age_range(@users, params[:age_range])              if params[:age_range].present?
        end

        private

        def apply_age_range(scope, range)
          case range
          when '18-25' then scope.filter_by_age(18, 25)
          when '26-35' then scope.filter_by_age(26, 35)
          when '36-45' then scope.filter_by_age(36, 45)
          when '46+'   then scope.filter_by_age(46, 120)
          else scope
          end
        end
      end
    end
  end
end
