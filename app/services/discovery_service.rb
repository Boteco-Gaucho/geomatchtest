# app/services/discovery_service.rb
class DiscoveryService
  include Rails.application.routes.url_helpers

  def initialize(user)
    @user = user
  end

  # origin: posição de quem olha (o GPS do pedido). Quem está oculto ou com a
  # localização desligada não grava a posição no banco, então ela vem daqui.
  # O raio nunca passa de User::MAP_RADIUS_KM ("Só quem está perto te vê").
  def find_nearby_users(radius_km = User::MAP_RADIUS_KM, gender_filter = nil, origin: nil)
    origin ||= [ @user.latitude, @user.longitude ]
    return [] if origin.any?(&:blank?)

    radius_km = [ radius_km.to_f, User::MAP_RADIUS_KM ].min

    # Só retorna utilizadores que estão online (ativos nos últimos 5 min).
    # Quem fechar o app sem logout desaparece após 5 min de inatividade.
    # Bloqueios breves de ecrã sobrevivem porque o presence.js re-bate ao desbloquear.
    query = User.near(origin, radius_km)
                .online_on_map
                .where.not(id: @user.id)
                .visible # modo oculto e conta congelada ficam de fora
                .sharing_location
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

    # Coração da prévia do pin (map_3d.js) já marcado em quem a pessoa curtiu
    liked_ids = @user.likes.where(is_like: [ true, nil ]).pluck(:liked_id).to_set

    query.map do |u|
      # Posição aproximada (nunca a do GPS) e distância até ela — limitada ao raio,
      # porque a pessoa de fato está dentro dele (o filtro acima usa a posição real)
      approx_lat, approx_lng = u.approximate_coordinates
      distance = [
        Geocoder::Calculations.distance_between(origin, [ approx_lat, approx_lng ]),
        radius_km
      ].min.round(3)

      {
        id: u.id,
        username: u.username,
        latitude: approx_lat,
        longitude: approx_lng,
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
        age: u.public_age, # nil quando a pessoa escondeu a idade (Gold)
        liked: liked_ids.include?(u.id)
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