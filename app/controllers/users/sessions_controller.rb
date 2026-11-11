class Users::SessionsController < Devise::SessionsController
  skip_before_action :verify_authenticity_token, only: :destroy

  def destroy
    if current_user
      # 1. Remove o marcador do mapa de todos os clientes conectados imediatamente.
      ActionCable.server.broadcast("map_updates", {
        action:  "leave",
        user_id: current_user.id
      })

      # 2. Apaga as coordenadas do banco para que o usuário não reapareça em
      #    localização antiga caso outro usuário recarregue o mapa antes de logar novamente.
      current_user.update_columns(
        latitude:                 nil,
        longitude:                nil,
        last_location_updated_at: nil
      )
    end

    sign_out current_user
    render json: { success: true }, status: :ok
  end
end
