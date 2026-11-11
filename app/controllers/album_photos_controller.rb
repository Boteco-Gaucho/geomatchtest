# app/controllers/album_photos_controller.rb

class AlbumPhotosController < ApplicationController
  # Garante que apenas usuários logados possam acessar
  before_action :authenticate_user!

  def destroy
    # 1. Encontra o anexo do Active Storage pelo ID
    photo = ActiveStorage::Attachment.find(params[:id])

    # 2. Verifica se o anexo pertence ao usuário logado (SEGURANÇA CRÍTICA)
    if photo.record == current_user
      photo.purge # Exclui o arquivo do storage e o registro do banco de dados
      flash[:notice] = "Foto removida do álbum."
    else
      flash[:alert] = "Você não tem permissão para excluir esta foto."
    end

    # 3. Redireciona de volta para a página de perfil
    redirect_back fallback_location: edit_profile_path
  end
end
