class Api::LocationsController < ApplicationController
  # Desativa a verificação do token web para esta chamada de API nativa
  skip_before_action :verify_authenticity_token

  def update
    # O Android vai enviar os parâmetros via JSON. 
    # Vamos assumir que ele envia: user_id, latitude e longitude.
    
    user = User.find_by(id: params[:user_id])

    if user
      # Atualiza as coordenadas do usuário no banco de dados
      if user.update(latitude: params[:latitude], longitude: params[:longitude])
        render json: { status: 'sucesso', message: 'Localização atualizada com sucesso' }, status: :ok
      else
        render json: { status: 'erro', message: 'Falha ao salvar as coordenadas' }, status: :unprocessable_entity
      end
    else
      render json: { status: 'erro', message: 'Usuário não encontrado' }, status: :not_found
    end
  end
end