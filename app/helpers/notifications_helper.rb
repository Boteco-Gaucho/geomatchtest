module NotificationsHelper
  # "~150 m de você" / "~1,2 km de você": distância APROXIMADA (múltiplos de
  # 50 m) entre quem vê e a outra pessoa. Não aparece se faltar localização de
  # alguém ou se a pessoa estiver invisível / tiver desligado o compartilhamento.
  # suffix: false devolve só "~150 m" (pílula dos cards borrados do plano grátis).
  def approx_distance_from_you(viewer, other, suffix: true)
    km = shared_distance_km(viewer, other) or return nil
    label = approx_km_label(km)

    suffix ? "#{label} de você" : label
  end

  # "~150 m" (múltiplos de 50 m) / "~1,2 km" / "~12 km"
  def approx_km_label(km)
    meters = ((km * 1000) / 50.0).round * 50

    if meters < 1000 then "~#{[ meters, 50 ].max} m"
    elsif km < 10    then "~#{('%.1f' % km).tr('.', ',')} km"
    else                  "~#{km.round} km"
    end
  end

  # Card do /lead: dentro do raio do GeoMatch (300 m) diz só "Menos de 300 m de você";
  # mais longe, a distância aproximada acima. Mesmas regras de privacidade.
  def nearby_distance_label(viewer, other)
    km = shared_distance_km(viewer, other) or return nil
    km < 0.3 ? "Menos de 300 m de você" : approx_distance_from_you(viewer, other)
  end

  # Distância em km — nil se faltar localização ou se a pessoa estiver invisível /
  # tiver desligado o compartilhamento
  def shared_distance_km(viewer, other)
    return nil if other.invisible? || other.share_location == false
    return nil if [ viewer.latitude, viewer.longitude, other.latitude, other.longitude ].any?(&:blank?)

    Geocoder::Calculations.distance_between(
      [ viewer.latitude, viewer.longitude ], [ other.latitude, other.longitude ], units: :km
    )
  end

  # Preço do painel de upgrade: "R$ 49,90/mês" (ou "a cada N meses").
  def plan_price_per_period(plan)
    months = plan.duration_months.to_i
    months <= 1 ? "#{plan.price.format}/mês" : "#{plan.price.format} a cada #{months} meses"
  end

  # Pílula "Ativa agora" dos cards — só para quem está online e não invisível.
  def online_now_label(user)
    return nil unless user.online? && !user.invisible?

    case user.gender
    when "Mulher" then "Ativa agora"
    when "Homem"  then "Ativo agora"
    else               "Online agora"
    end
  end
end
