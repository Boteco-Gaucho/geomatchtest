# Troca da foto principal (UsersController#apply_crop): a foto anterior fica guardada por
# AVATAR_UNDO_WINDOW para o "Desfazer" do aviso "Foto atualizada". Passado esse tempo, se
# ninguém voltou a usá-la, o arquivo é apagado.
class AvatarUndoCleanupJob < ApplicationJob
  queue_as :default

  def perform(blob_id)
    blob = ActiveStorage::Blob.find_by(id: blob_id)
    blob.purge if blob && blob.attachments.none?
  end
end
