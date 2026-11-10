# Troca da foto principal (UsersController#apply_crop) e foto removida do álbum
# (AlbumPhotosController#destroy): o arquivo fica guardado por um tempo para o "Desfazer" do
# aviso. Passado esse tempo, se ninguém voltou a usá-lo, é apagado.
class AvatarUndoCleanupJob < ApplicationJob
  queue_as :default

  def perform(blob_id)
    blob = ActiveStorage::Blob.find_by(id: blob_id)
    blob.purge if blob && blob.attachments.none?
  end
end
