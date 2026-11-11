class MessageBroadcastJob < ApplicationJob
  queue_as :default

  def perform(message)
    ActionCable.server.broadcast "match_#{message.match_id}", message: render_message(message)
  end

  private

  def render_message(message)
    {
      id: message.id,
      content: message.content,
      sender_id: message.sender_id,
      match_id: message.match_id,
      created_at: message.created_at.iso8601,
      display_name: message.sender.display_name,
      avatar_url: message.sender.avatar_url
    }
  end
end
