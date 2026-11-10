# app/controllers/album_photos_controller.rb
#
# Remover foto do álbum (Editar perfil, X da foto): a foto sai do perfil na hora e aparece o
# aviso "Foto removida — Você ainda tem N fotos no perfil." com Desfazer
# (shared/_photo_removed_toast). O arquivo fica guardado por UNDO_WINDOW; o Desfazer devolve
# a foto na mesma posição. O id fica na sessão (no servidor): só a SUA foto volta.
class AlbumPhotosController < ApplicationController
  # Garante que apenas usuários logados possam acessar
  before_action :authenticate_user!

  UNDO_WINDOW = 10.minutes

  def destroy
    photo = ActiveStorage::Attachment.find_by(id: params[:id], name: "album_photos")

    # Verifica se o anexo pertence ao usuário logado (SEGURANÇA CRÍTICA)
    unless photo && photo.record == current_user
      flash[:alert] = "Você não tem permissão para excluir esta foto."
      return redirect_back fallback_location: edit_profile_path
    end

    position = current_user.album_photos_attachments.pluck(:id).index(photo.id) || 0
    blob_id  = photo.blob_id
    photo.delete # tira do perfil sem apagar o arquivo (o Desfazer ainda pode devolver)
    current_user.album_photos_attachments.reset

    session[:album_undo] = { "blob_id" => blob_id, "position" => position, "until" => UNDO_WINDOW.from_now.to_i }
    AvatarUndoCleanupJob.set(wait: UNDO_WINDOW).perform_later(blob_id) # apaga se ninguém desfizer
    flash[:photo_removed] = photos_left
    redirect_back fallback_location: edit_profile_path, status: :see_other
  end

  # POST /album_photos/undo — "Desfazer" do aviso "Foto removida"
  def undo
    undo = session.delete(:album_undo) || {}
    blob = ActiveStorage::Blob.find_by(id: undo["blob_id"]) if undo["until"].to_i > Time.current.to_i

    if blob.nil?
      flash[:alert] = "Não dá mais para desfazer a remoção da foto."
    elsif current_user.album_photos_attachments.count >= User::ALBUM_PHOTOS_LIMIT
      flash[:alert] = "Seu álbum está cheio. Remova uma foto para trazer esta de volta."
      session[:album_undo] = undo # ainda dá para tentar de novo dentro do prazo
    else
      current_user.album_photos.attach(blob)
      ids = current_user.album_photos_attachments.reset.pluck(:id)
      restored = ids.pop
      ids.insert([ undo["position"].to_i, ids.size ].min, restored) # volta para a mesma posição
      current_user.reorder_album_photos!(ids)
      flash[:photo_removed] = "restored"
    end
    redirect_to edit_profile_path, status: :see_other
  end

  private

  # Fotos que continuam no perfil: a principal (se for de verdade) + as do álbum
  def photos_left
    current_user.album_photos_attachments.count + (current_user.has_real_avatar? ? 1 : 0)
  end
end
