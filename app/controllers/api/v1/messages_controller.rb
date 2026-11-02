module Api
  module V1
    # GET /api/v1/messages?match_id=<id>
    class MessagesController < BaseController
      def index
        @match = current_api_user.matches.find_by(id: params[:match_id])
        return api_not_found('Conversa não encontrada.') unless @match

        # Sem o que a pessoa apagou para si / limpou na web
        @messages = @match.messages.visible_to(current_api_user)
          .order(created_at: :asc)
          .includes(:sender, :reactions)
      end
    end
  end
end
