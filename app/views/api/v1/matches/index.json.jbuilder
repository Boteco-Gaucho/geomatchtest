json.matches @matches do |match|
  other        = match.other_user(current_api_user)
  last_message = match.messages.order(created_at: :desc).first

  json.id         match.id
  json.created_at match.created_at.iso8601

  json.other_user do
    json.id         other.id
    json.name       other.display_name
    json.avatar_url other.avatar_url
    json.online     other.online?
    json.verified   other&.verified?

    # Distância em km — só se ambos tiverem coordenadas
    if current_api_user.latitude.present? && other.latitude.present?
      json.distance_km Geocoder::Calculations.distance_between(
        [current_api_user.latitude,  current_api_user.longitude],
        [other.latitude, other.longitude],
        units: :km
      ).round(1)
    else
      json.distance_km nil
    end
  end

  json.last_message do
    if last_message
      json.content    last_message.content.truncate(80)
      json.sent_at    last_message.created_at.iso8601
      json.is_mine    last_message.sender_id == current_api_user.id
    else
      json.content    nil
      json.sent_at    nil
      json.is_mine    nil
    end
  end
end
