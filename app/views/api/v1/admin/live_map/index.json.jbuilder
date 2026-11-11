# JSON intencionalmente minimalista para performance do mapa.
# Sem nomes, sem fotos — apenas coordenadas e status.

json.count @users.size

json.users @users do |user|
  json.id           user.id
  json.lat          user.latitude
  json.lng          user.longitude
  json.is_online    user.last_seen_at.present? && user.last_seen_at > 2.minutes.ago
  json.is_invisible user.invisible?
  json.last_seen_at user.last_seen_at&.iso8601
end
