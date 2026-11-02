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
