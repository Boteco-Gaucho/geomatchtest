class Like < ApplicationRecord
  # Curtir pelo mapa (/discover_3d — like_toggle_controller.js) pode ser desfeito por um
  # tempo: um novo toque no coração dentro desta janela descurte (LikesController#destroy).
  # Passado o tempo, a curtida fica valendo. Ajustável com LIKE_UNDO_SECONDS.
  UNDO_WINDOW = ENV.fetch("LIKE_UNDO_SECONDS", 8).to_i.seconds

  belongs_to :liker, class_name: "User"
  belongs_to :liked, class_name: "User"

  validates :liker_id, uniqueness: { scope: :liked_id }

  scope :positive, -> { where(is_like: [ true, nil ]) }

  # Segundos que ainda restam para desfazer (0 = já vale)
  def undo_seconds_left(now = Time.current)
    left = (created_at + UNDO_WINDOW - now).ceil
    left.positive? ? left : 0
  end

  def undoable?
    undo_seconds_left.positive?
  end
end
