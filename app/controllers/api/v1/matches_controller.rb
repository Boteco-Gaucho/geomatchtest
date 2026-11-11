module Api
  module V1
    # GET /api/v1/matches
    class MatchesController < BaseController
      def index
        # Matches com mensagens, ordenados pela mais recente
        @matches = current_api_user.matches
          .joins(:messages)
          .select('matches.*, MAX(messages.created_at) AS last_msg_at')
          .group('matches.id')
          .order('MAX(messages.created_at) DESC')
          .includes(:user, :matched_user)
      end
    end
  end
end
