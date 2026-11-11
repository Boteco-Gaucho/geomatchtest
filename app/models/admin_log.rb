class AdminLog < ApplicationRecord
  belongs_to :admin, class_name: 'User', foreign_key: :admin_id

  validates :action,      presence: true
  validates :target_id,   presence: true
  validates :target_type, presence: true

  scope :latest_first, -> { order(created_at: :desc) }
  scope :for_target,   ->(type, id) { where(target_type: type, target_id: id) }
  scope :by_admin,     ->(id) { where(admin_id: id) }
  scope :by_action,    ->(action) { where(action: action) }
end
