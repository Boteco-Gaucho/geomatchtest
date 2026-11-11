# app/services/discovery_service.rb
class DiscoveryService
  include Rails.application.routes.url_helpers

  def initialize(user)
    @user = user
  end

  def find_nearby_users(radius_km = 10, gender_filter = nil)
    return [] unless @user.latitude && @user.longitude

    # Só retorna utilizadores que estão online (ativos nos últimos 5 min).
    # Quem fechar o app sem logout desaparece após 5 min de inatividade.
    # Bloqueios breves de ecrã sobrevivem porque o presence.js re-bate ao desbloquear.
    query = User.near([@user.latitude, @user.longitude], radius_km)
                .online_on_map
                .where.not(id: @user.id)
                .where(invisible: [false, nil])
                .with_attached_avatar
                .with_attached_album_photos

    if gender_filter.present? && gender_filter != "all"
      # Cada chave mapeia para todos os valores que o campo gender pode ter no banco.
      # "nao binario" (sem acento) cobre registros antigos migrados sem normalização.
      mapping = {
        "male"       => ["homem"],
        "female"     => ["mulher"],
        "non-binary" => ["não binário", "nao binario", "não-binário"]
      }

      target_values = mapping[gender_filter]

      if target_values
        query = query.where("LOWER(gender) IN (?)", target_values)
      end
    end

    query.map do |u|
      distance = Geocoder::Calculations.distance_between(
        [@user.latitude, @user.longitude],
        [u.latitude, u.longitude]
      ).round(3)  # 3 casas = precisão de ~1m; .round(1) truncava 70m→0.1km, quebrando filtros curtos

      {
        id: u.id,
        username: u.username,
        latitude: u.latitude,
        longitude: u.longitude,
        gender: u.gender,
        city: u.city,
        bio: u.bio,
        interested_in: u.interested_in,
        hobbies_list: u.hobbies_list,
        avatar_url: effective_avatar_path(u),
        distance_km: distance,
        last_seen_at: u.last_seen_at,
        verified: u.verified,
        photos_urls: build_photos_urls(u),
        age: u.birthdate.present? ? ((Date.today - u.birthdate.to_date) / 365.25).floor : nil
      }
    end
  end

  private

  # Retorna o path do avatar principal; se ausente, usa a 1ª foto do álbum.
  # Ambos os escopos (avatar + album_photos) são pré-carregados na query principal
  # via with_attached_avatar + with_attached_album_photos — zero queries extras.
  def effective_avatar_path(user)
    if user.avatar.attached?
      rails_blob_path(user.avatar, only_path: true)
    elsif (first_album = user.album_photos.first)
      rails_blob_path(first_album, only_path: true)
    end
  end

  def build_photos_urls(user)
    urls = []
    urls << rails_blob_path(user.avatar, only_path: true) if user.avatar.attached?
    user.album_photos.each { |p| urls << rails_blob_path(p, only_path: true) }
    urls
  end
end