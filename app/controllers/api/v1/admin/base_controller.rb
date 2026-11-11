module Api
  module V1
    module Admin
      # Herda toda a autenticação JWT de V1::BaseController.
      # Adiciona a camada de autorização: apenas usuários admin passam.
      class BaseController < Api::V1::BaseController
        before_action :require_admin!

        private

        def require_admin!
          unless current_api_user&.admin?
            render json: {
              error:  'Acesso negado.',
              detail: 'Esta área é restrita a administradores.'
            }, status: :forbidden
          end
        end
      end
    end
  end
end
