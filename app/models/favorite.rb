class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :favorited_user, class_name: 'User'

  validates :favorited_user_id, uniqueness: { scope: :user_id }
end
