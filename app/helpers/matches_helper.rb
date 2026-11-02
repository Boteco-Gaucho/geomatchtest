module MatchesHelper
  WEEKDAYS_SHORT = %w[Dom Seg Ter Qua Qui Sex Sáb].freeze
  WEEKDAYS_LONG  = %w[Domingo Segunda-feira Terça-feira Quarta-feira Quinta-feira Sexta-feira Sábado].freeze
  MONTHS = %w[janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro].freeze

  # Sugestões acima do campo da conversa (tocar preenche o campo)
  QUICK_REPLIES = [ "Oi! Tudo bem?", "E aí, beleza?", "Como tá seu dia?" ].freeze

  # Lista de conversas: "12:48" hoje, "Ontem", "Seg" na mesma semana, senão "12/10"
  def conversation_time_label(time)
    return "" unless time

    date  = time.to_date
    today = Date.current
    if date == today then time.strftime("%H:%M")
    elsif date == today - 1 then "Ontem"
    elsif date > today - 7 then WEEKDAYS_SHORT[date.wday]
    else date.strftime("%d/%m")
    end
  end

  # Separador de dia na conversa: "Hoje", "Ontem", "Segunda-feira", senão "12 de outubro"
  def chat_day_label(date)
    today = Date.current
    if date == today then "Hoje"
    elsif date == today - 1 then "Ontem"
    elsif date > today - 7 then WEEKDAYS_LONG[date.wday]
    else
      label = "#{date.day} de #{MONTHS[date.month - 1]}"
      date.year == today.year ? label : "#{label} de #{date.year}"
    end
  end

  # Abaixo do nome no topo da conversa ("Ativo agora" respeita o modo invisível)
  def chat_status_label(user)
    online_now_label(user) || "Offline"
  end

  # Chip do começo da conversa. A distância é a de quando a conexão aconteceu
  # (Match#distance_m); conversas antigas ou de quem não compartilha a
  # localização mostram como ela começou.
  def connection_chip_text(match, viewer)
    other    = match.other_user(viewer)
    distance = match.has_attribute?(:distance_m) ? match.distance_m : nil
    sharing  = [ viewer, other ].none? { |person| person.share_location == false }

    if distance && sharing
      distance < 300 ? "Vocês se conectaram a menos de 300 m" : "Vocês se conectaram a #{approx_km_label(distance / 1000.0)}"
    elsif mutual_match?(viewer, other)
      "Vocês deram match"
    elsif match.user_id == viewer.id
      "Você iniciou a conversa"
    else
      "#{other.display_name.split.first} iniciou a conversa"
    end
  end

  private

  def mutual_match?(viewer, other)
    Like.exists?(liker_id: viewer.id, liked_id: other.id) && Like.exists?(liker_id: other.id, liked_id: viewer.id)
  end
end
