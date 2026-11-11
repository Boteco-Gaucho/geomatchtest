module Api
  module V1
    module Admin
      class SettingsController < Api::V1::Admin::BaseController
        # GET /api/v1/admin/settings
        def index
          settings = Setting.order(:key).map { |s| serialize(s) }
          render json: { settings: settings }, status: :ok
        end

        # PATCH /api/v1/admin/settings/:id
        def update
          setting = Setting.find(params[:id])

          if setting.update(value: params.require(:setting).require(:value))
            render json: {
              message: 'Configuração atualizada com sucesso.',
              setting: serialize(setting)
            }, status: :ok
          else
            render json: {
              error: 'Erro ao atualizar configuração.',
              details: setting.errors.full_messages
            }, status: :unprocessable_entity
          end
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Configuração não encontrada.' }, status: :not_found
        end

        private

        def serialize(setting)
          {
            id:                setting.id,
            key:               setting.key,
            value:             setting.value,
            value_formatted:   format_value(setting),
            updated_at:        setting.updated_at
          }
        end

        def format_value(setting)
          case setting.key
          when 'one_off_message_price'
            "R$ #{format('%.2f', setting.value / 100.0).tr('.', ',')}"
          else
            setting.value.to_s
          end
        end
      end
    end
  end
end
