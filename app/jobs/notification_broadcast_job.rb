# app/jobs/notification_broadcast_job.rb
class NotificationBroadcastJob < ApplicationJob
  queue_as :default

  # Curtida desfeita dentro da janela (Like::UNDO_WINDOW): a notificação foi apagada antes
  # de o job rodar — não há o que enviar
  discard_on ActiveJob::DeserializationError

  # Avisa o navegador de quem recebeu: o número de "Te curtiram" (a mesma regra da lista)
  # e o tipo. Antes renderizava o card da aba aqui — o card usa current_user, que não
  # existe num job, e o envio falhava; o app web nem escutava o canal.
  def perform(notification)
    recipient = notification.recipient
    return unless recipient

    NotificationChannel.broadcast_to(
      recipient,
      kind:  notification.notifiable_type.to_s.underscore, # like / match / mimo_transaction
      count: recipient.unseen_likes_count
    )
  end
end
