class Message < ApplicationRecord
  include GlobalID::Identification

  enum :status, { sent: 0, delivered: 1, read: 2 }, default: :sent

  belongs_to :match
  belongs_to :sender, class_name: "User"
  has_many   :reactions, dependent: :destroy

  validates :content, presence: true

  after_create_commit  :broadcast_message
  after_create_commit  :send_push_notification
  after_destroy_commit :broadcast_deletion

  private

  def broadcast_message
    payload = {
      message: {
        id:         id,
        match_id:   match_id,
        content:    content,
        sender_id:  sender_id,
        status:     status,
        created_at: created_at.iso8601,
        user_name:  sender.display_name || "Usuário",
        avatar_url: sender.avatar_url || "/assets/avatarfoto.jpg",
        verified:   sender.verified?
      }
    }

    MatchChannel.broadcast_to(match, payload)
  rescue => e
    Rails.logger.error "[Message#broadcast_message] Falha no broadcast match=#{match_id} error=#{e.class}: #{e.message}"
  end

  def broadcast_deletion
    MatchChannel.broadcast_to(match, { deleted_message_id: id })
  rescue => e
    Rails.logger.error "[Message#broadcast_deletion] Falha no broadcast match=#{match_id} error=#{e.class}: #{e.message}"
  end

  def send_push_notification
    Rails.logger.info "[Message] Enfileirando PushNotificationJob para message=#{id} match=#{match_id}"
    PushNotificationJob.perform_later(id)
  rescue => e
    Rails.logger.error "[Message#send_push_notification] Falha ao enfileirar job message=#{id} error=#{e.class}: #{e.message}"
  end
end
