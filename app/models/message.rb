class Message < ApplicationRecord
  include GlobalID::Identification

  enum :status, { sent: 0, delivered: 1, read: 2 }, default: :sent

  # Tamanho do trecho da mensagem citada (balão e barra "Respondendo a…").
  REPLY_PREVIEW_LENGTH = 120

  # "Editar" a própria mensagem: até 15 min depois de enviar (como no WhatsApp)
  EDIT_WINDOW = 15.minutes
  # "Apagar para todos": enquanto não foi vista, ou até 3 min depois de vista
  DELETE_FOR_EVERYONE_WINDOW = 3.minutes

  # Colunas do chat novo (migration AddChatControls). Em produção o banco é
  # ajustado à mão: até elas existirem o chat segue funcionando, só sem editar
  # e sem "apagar para mim".
  def self.chat_controls?
    (%w[edited_at hidden_for_user_ids] - column_names).empty?
  end

  # Mensagens que a pessoa não apagou para si ("Apagar para mim" / "Limpar conversa")
  scope :visible_to, ->(user) {
    chat_controls? ? where.not("? = ANY(messages.hidden_for_user_ids)", user.id) : all
  }

  belongs_to :match
  belongs_to :sender, class_name: "User"
  # Mensagem respondida (arrastar para a direita no chat). Se a original for
  # apagada, o banco zera esta coluna (on_delete: :nullify).
  belongs_to :reply_to, class_name: "Message", optional: true
  has_many   :reactions, dependent: :destroy

  validates :content, presence: true
  validate  :reply_to_must_belong_to_same_match

  after_create_commit  :broadcast_message
  after_create_commit  :send_push_notification
  after_destroy_commit :broadcast_deletion

  def edited?
    has_attribute?(:edited_at) && edited_at.present?
  end

  def editable_by?(user)
    Message.chat_controls? && sender_id == user&.id && created_at > EDIT_WINDOW.ago
  end

  # Só quem enviou; mensagem lida antes de existir read_at conta como vista há
  # muito tempo (não dá mais para apagar para todos)
  def deletable_for_everyone_by?(user)
    return false unless sender_id == user&.id
    return true unless read?

    read_at.present? && read_at > DELETE_FOR_EVERYONE_WINDOW.ago
  end

  def edit!(new_content)
    update!(content: new_content, edited_at: Time.current)
    broadcast_edit
  end

  # "Apagar para mim": some só para quem pediu
  def hide_for!(user)
    return false unless Message.chat_controls?

    Message.where(id: id).hide_for_all!(user)
    true
  end

  def self.hide_for_all!(user)
    where.not("? = ANY(messages.hidden_for_user_ids)", user.id)
      .update_all([ "hidden_for_user_ids = array_append(hidden_for_user_ids, ?)", user.id ])
  end

  # Resumo da mensagem citada, no formato que o chat_logic.js desenha.
  def reply_to_preview
    return nil unless reply_to

    {
      id:          reply_to.id,
      sender_id:   reply_to.sender_id,
      sender_name: reply_to.sender&.display_name || "Usuário",
      content:     reply_to.content.to_s.truncate(REPLY_PREVIEW_LENGTH)
    }
  end

  private

  # A citação só pode apontar para uma mensagem desta conversa: um reply_to_id
  # forjado vazaria, no broadcast, o conteúdo de uma conversa de outras pessoas.
  def reply_to_must_belong_to_same_match
    return if reply_to_id.blank?
    return if reply_to && reply_to.match_id == match_id

    errors.add(:reply_to, "precisa ser uma mensagem desta conversa")
  end

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
        verified:   sender.verified?,
        reply_to:   reply_to_preview
      }
    }

    MatchChannel.broadcast_to(match, payload)
  rescue => e
    Rails.logger.error "[Message#broadcast_message] Falha no broadcast match=#{match_id} error=#{e.class}: #{e.message}"
  end

  def broadcast_edit
    MatchChannel.broadcast_to(match, {
      edited_message: { id: id, content: content, edited_at: edited_at.iso8601 }
    })
  rescue => e
    Rails.logger.error "[Message#broadcast_edit] Falha no broadcast match=#{match_id} error=#{e.class}: #{e.message}"
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
