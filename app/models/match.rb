class Match < ApplicationRecord
  include GlobalID::Identification
  belongs_to :user
  belongs_to :matched_user, class_name: "User"

  has_many :messages, dependent: :destroy

  before_create :remember_distance

  # Colunas do chat novo (migration AddChatControls) — ver Message.chat_controls?
  def self.chat_controls?
    (%w[muted_by_user_ids distance_m] - column_names).empty?
  end

  # "Silenciar notificações": a conversa não manda push para essa pessoa
  def muted_for?(user)
    has_attribute?(:muted_by_user_ids) && muted_by_user_ids.include?(user&.id)
  end

  def toggle_mute!(user)
    return false unless Match.chat_controls?

    ids = muted_by_user_ids
    update!(muted_by_user_ids: ids.include?(user.id) ? ids - [ user.id ] : ids + [ user.id ])
    true
  end

  # "Limpar conversa": as mensagens somem só para quem pediu (como no WhatsApp);
  # a outra pessoa continua com o histórico
  def clear_for!(user)
    return false unless Message.chat_controls?

    messages.hide_for_all!(user)
    true
  end

  # Abrir a conversa = ler tudo o que chegou (como no WhatsApp). Antes só contava como lida
  # a mensagem que aparecia na tela com o WebSocket já conectado: as de cima nunca eram
  # marcadas e, sem conexão, nenhuma — o número da lista /matches não zerava.
  # Uma única UPDATE e um único aviso para quem enviou (tiques azuis). Devolve quantas.
  def mark_read_by!(reader)
    return 0 unless participant?(reader)

    ids = messages.where.not(sender_id: reader.id).where.not(status: :read).pluck(:id)
    return 0 if ids.empty?

    now = Time.current
    Message.where(id: ids).update_all(status: Message.statuses[:read], read_at: now, updated_at: now)
    begin
      MatchChannel.broadcast_to(self, { action: "status_update", message_ids: ids, status: "read", read_at: now.iso8601 })
    rescue => e
      Rails.logger.error "[Match#mark_read_by!] Falha no broadcast match=#{id} error=#{e.class}: #{e.message}"
    end
    ids.size
  end

  # "Desfazer match" (menu da conversa): apaga a conversa dos dois e as notificações do
  # match. A curtida de quem desfez vira "agora não" (Like is_like: false): o match não se
  # refaz sozinho, a pessoa não volta na descoberta e some de "Te curtiram".
  # Quem tinha a conversa aberta é avisado (MatchChannel { unmatched: true }).
  def unmatch_by!(user)
    return false unless participant?(user)

    other = other_user(user)
    begin
      MatchChannel.broadcast_to(self, { unmatched: true, user_id: user.id })
    rescue => e
      Rails.logger.error "[Match#unmatch_by!] Falha no broadcast match=#{id} error=#{e.class}: #{e.message}"
    end

    transaction do
      if other
        like = Like.find_by(liker_id: user.id, liked_id: other.id)
        like ? like.update!(is_like: false) : Like.create!(liker_id: user.id, liked_id: other.id, is_like: false)
      end
      Notification.where(notifiable: self).delete_all
      # Em lote: sem um broadcast de "mensagem apagada" por mensagem
      message_ids = messages.ids
      Reaction.where(message_id: message_ids).delete_all
      Message.where(id: message_ids).update_all(reply_to_id: nil)
      Message.where(id: message_ids).delete_all
      destroy!
    end
    true
  end

  def other_user(current_user)
    current_user == user ? matched_user : user
  end

  def participant?(user)
    user && (user_id == user.id || matched_user_id == user.id)
  end

   # Novo método para verificar se a conversa foi iniciada
  def initiated_conversation?
    messages.exists?
  end

  scope :for_user, ->(user_id) { where("user_id = ? OR matched_user_id = ?", user_id, user_id) }

  private

  # Distância entre as duas pessoas quando a conexão aconteceu (chip
  # "Vocês se conectaram a menos de 300 m" no começo da conversa)
  def remember_distance
    return unless has_attribute?(:distance_m) && user && matched_user

    points = [ [ user.latitude, user.longitude ], [ matched_user.latitude, matched_user.longitude ] ]
    return if points.flatten.any?(&:blank?)

    self.distance_m = (Geocoder::Calculations.distance_between(*points, units: :km) * 1000).round
  end
end
