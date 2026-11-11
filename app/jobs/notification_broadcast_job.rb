# app/jobs/notification_broadcast_job.rb
class NotificationBroadcastJob < ApplicationJob
  queue_as :default

  def perform(notification)
    # Renderiza a notificação como HTML parcial
    html = ApplicationController.render(
      partial: 'notifications/notification',
      locals: { notification: notification }
    )
    
    # Transmite o HTML para o canal do usuário que recebeu a notificação
    NotificationChannel.broadcast_to(
      notification.recipient,
      html: html,
      count: notification.recipient.notifications.unread.count
    )
  end
end
