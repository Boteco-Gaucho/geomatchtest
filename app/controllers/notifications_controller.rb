# app/controllers/notifications_controller.rb
class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    photo_includes = { avatar_attachment: :blob, album_photos_attachments: :blob }

    # 1. Notificações (Quem te curtiu)
    @notifications = current_user.notifications
      .includes(actor: photo_includes)
      .order(created_at: :desc)

    # 2. Quem VOCÊ curtiu
    @my_likes = Like.where(liker_id: current_user.id)
      .includes(liked: photo_includes)
      .order(created_at: :desc)

    # Marca todas como lidas ao visitar a página
    current_user.notifications.unread.update_all(read_at: Time.current)
  end
end