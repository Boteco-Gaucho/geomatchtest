class NotificationChannel < ApplicationCable::Channel
  def subscribed
   # O canal se inscreve em um stream específico para o usuário logado
    stream_for current_user
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
