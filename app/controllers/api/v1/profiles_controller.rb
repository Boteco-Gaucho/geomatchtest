module Api
  module V1
    # PATCH /api/v1/profile/survey
    # Endpoint para o usuário preencher dados do perfil estendido
    class ProfilesController < BaseController
      ALLOWED_EDUCATION_LEVELS = %w[
        fundamental_incompleto fundamental_completo
        medio_incompleto medio_completo
        superior_incompleto superior_completo
        pos_graduacao mestrado doutorado
      ].freeze

      def update_survey
        user = current_api_user

        if user.update(survey_params)
          render json: {
            success: true,
            education_level:     user.education_level,
            occupation:          user.occupation,
            political_interests: user.political_interests
          }
        else
          render json: { success: false, errors: user.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      private

      def survey_params
        params.require(:profile).permit(
          :education_level,
          :occupation,
          political_interests: []
        )
      end
    end
  end
end
