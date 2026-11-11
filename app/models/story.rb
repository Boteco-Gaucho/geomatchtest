# app/models/story.rb
class Story < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :user

  # Configuração do Active Storage para anexar a mídia (foto ou vídeo)
  has_one_attached :media

  # Validações
  validates :media, presence: true

  # Geocoder: Opcional, mas útil para buscas baseadas em localização
  # Se você não estiver usando o Geocoder, remova as linhas abaixo
   reverse_geocoded_by :latitude, :longitude do |obj, results|
     if geo = results.first
       obj.city    = geo.city
       obj.country = geo.country
     end
   end
   after_validation :reverse_geocode, if: -> { latitude_changed? || longitude_changed? }

  # Escopo para buscar stories próximos (exemplo: 50 km)
  # O Geocoder gem (confirmado no Gemfile) facilita isso.
  scope :nearby, ->(lat, lng, radius = 50) {
    near([lat, lng], radius, units: :km)
  }

  # Método para serialização JSON para o frontend
  def as_json(options = {})
    super(options).merge({
      user_name: user.username, # Assumindo que o User tem um campo 'username'
      user_avatar_url: user.avatar_url, # Assumindo que o User tem um método 'avatar_url'
      media_url: media.attached? ? Rails.application.routes.url_helpers.rails_blob_url(media, only_path: true) : nil,
      media_type: media.attached? ? media.content_type.split('/').first : nil
    })
  end
end