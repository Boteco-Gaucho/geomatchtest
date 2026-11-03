class Report < ApplicationRecord
  belongs_to :reporter, class_name: 'User', optional: true
  # "Sobre quem?" (opcional) — coluna nova, ver Report.reported_user_column?
  belongs_to :reported_user, class_name: "User", optional: true

  has_many_attached :photos

  CATEGORIES = %w[harassment fake_profile spam inappropriate_content underage scam unsafe_date other].freeze

  # Chips "O que aconteceu?" da tela Fazer uma denúncia, na ordem do mockup
  FORM_CATEGORIES = {
    "fake_profile"          => "Perfil falso",
    "harassment"            => "Assédio",
    "inappropriate_content" => "Mensagens ofensivas",
    "scam"                  => "Golpe ou pedido de dinheiro",
    "unsafe_date"           => "Encontro inseguro",
    "other"                 => "Outro"
  }.freeze

  DESCRIPTION_MAX = 1000
  MAX_PHOTOS      = 3
  MAX_PHOTO_SIZE  = 10.megabytes

  before_validation do
    self.category = "other" if category.blank?
    # O maxlength do navegador conta a quebra de linha como 1; o envio manda \r\n
    self.description = description.gsub("\r\n", "\n") if description
  end

  # Mensagens já em frase: a tela mostra error.message, sem o nome do atributo
  validates :description, presence: { message: "Conte o que houve." },
                          length: { maximum: DESCRIPTION_MAX, message: "O relato pode ter até #{DESCRIPTION_MAX} caracteres." }
  validates :category, inclusion: { in: CATEGORIES, message: "Escolha o que aconteceu." }
  validate :reported_user_is_someone_else
  validate :photos_are_a_few_images

  scope :pending,  -> { where(resolved_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }

  # Em produção a coluna é criada à mão (migrations desligadas); até lá o
  # "Sobre quem?" fica fora da tela em vez de quebrar a denúncia
  def self.reported_user_column?
    column_names.include?("reported_user_id")
  end

  def resolved?
    resolved_at.present?
  end

  def resolve!
    update!(resolved_at: Time.current)
  end

  private

  def reported_user_is_someone_else
    return unless has_attribute?(:reported_user_id) && reported_user_id.present?

    if reported_user.nil?
      errors.add(:reported_user, "Perfil não encontrado.")
    elsif reported_user_id == reporter_id
      errors.add(:reported_user, "Você não pode denunciar o próprio perfil.")
    end
  end

  def photos_are_a_few_images
    return unless photos.attached?

    errors.add(:photos, "Envie no máximo #{MAX_PHOTOS} fotos.") if photos.size > MAX_PHOTOS
    photos.each do |photo|
      next if photo.content_type.to_s.start_with?("image/") && photo.byte_size <= MAX_PHOTO_SIZE

      errors.add(:photos, "As fotos precisam ser imagens de até 10 MB.")
      break
    end
  end
end
