class Match < ApplicationRecord
  include GlobalID::Identification
  belongs_to :user
  belongs_to :matched_user, class_name: "User"

  has_many :messages, dependent: :destroy

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
end
