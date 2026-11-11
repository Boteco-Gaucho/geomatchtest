class MatchChannel < ApplicationCable::Channel
  def subscribed
    @match = Match.find_by(id: params[:match_id])
    user = connection.current_user

    unless @match && user && @match.participant?(user)
      reject
      return
    end

    # streaming correto
    stream_for @match
  end

  def unsubscribed
  end

  def receive(data)
    user = connection.current_user
    return unless @match && user && @match.participant?(user)

    MatchChannel.broadcast_to(@match, {
      typing:      !!data["typing"],
      user_id:     user.id,
      user_name:   user.display_name || "Usuário",
      user_avatar: user.avatar_url,
      verified:    user.verified?
    })
  end

  def mark_as_delivered(data)
    user = connection.current_user
    return unless @match && user && @match.participant?(user)

    message = @match.messages.find_by(id: data["message_id"])
    return unless message && message.sender_id != user.id
    return unless message.sent?

    message.update!(status: :delivered)
    MatchChannel.broadcast_to(@match, {
      action:     "status_update",
      message_id: message.id,
      status:     "delivered"
    })
  end

  def mark_as_read(data)
    user = connection.current_user
    return unless @match && user && @match.participant?(user)

    message = @match.messages.find_by(id: data["message_id"])
    return unless message && message.sender_id != user.id
    return if message.read?

    message.update!(status: :read)
    MatchChannel.broadcast_to(@match, {
      action:     "status_update",
      message_id: message.id,
      status:     "read"
    })
  end
end
