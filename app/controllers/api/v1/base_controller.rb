module Api
  module V1
    # Herda de ActionController::Base (não API) para suportar templates jbuilder.
    # Protegido via JWT — sem cookies de sessão Devise.
    class BaseController < ActionController::Base
      # Desativa CSRF (autenticação via header Authorization: Bearer)
      skip_before_action :verify_authenticity_token

      # Desativa comportamentos web que não fazem sentido na API
      skip_before_action :update_last_seen, raise: false
      skip_before_action :configure_permitted_parameters, raise: false

      before_action :authenticate_api_user!

      helper_method :current_api_user

      private

      def authenticate_api_user!
        header = request.headers['Authorization']
        token  = header&.split(' ')&.last

        return api_unauthorized('Token ausente') if token.blank?

        payload            = JwtService.decode(token)
        @current_api_user  = User.find(payload[:sub])

      rescue JWT::ExpiredSignature
        api_unauthorized('Token expirado. Faça login novamente.')
      rescue JWT::DecodeError
        api_unauthorized('Token inválido.')
      rescue ActiveRecord::RecordNotFound
        api_unauthorized('Usuário não encontrado.')
      end

      def current_api_user
        @current_api_user
      end

      def api_unauthorized(message)
        render json: { error: message }, status: :unauthorized
      end

      def api_not_found(message = 'Recurso não encontrado')
        render json: { error: message }, status: :not_found
      end
    end
  end
end
