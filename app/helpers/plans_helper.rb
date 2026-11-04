module PlansHelper
  # Lista de recursos dos cards de /plans (rótulo do mockup => chave em plans.features).
  # :soon = recurso que ainda não existe: aparece como "Em breve" e conta só no Gold.
  PLANS_PAGE_PERKS = [
    [ "Interação ilimitada no mapa", "likes_right_unlimited" ],
    [ "Ver quem curtiu você",        "see_who_liked_me" ],
    [ "Ver quem você curtiu",        "see_who_i_liked" ],
    [ "Mensagens ilimitadas",        "unlimited_messages" ],
    [ "Modo oculto",                 "allow_invisible" ],
    [ "Esconder minha idade",        :soon ],
    [ "Explorar outras cidades",     "search_by_distance" ],
    [ "Voltar perfil não curtido",   "rewind_profile" ]
  ].freeze

  # Frase de cada card; plano novo sem frase aqui usa plans.description
  PLAN_TAGLINES = {
    "gold" => "Tudo liberado. Veja sem ser visto e fale com quem quiser.",
    "plus" => "Descubra quem curtiu você e aproveite o mapa sem limites.",
    "free" => "Para começar: apareça no mapa e converse com quem está perto."
  }.freeze

  # Cores do card: gold / plus / free; outro plano pago usa as do Plus
  def plan_theme(plan)
    return plan.code if %w[gold plus free].include?(plan.code)

    plan.price_cents.to_i.zero? ? "free" : "plus"
  end

  def plan_tagline(plan)
    PLAN_TAGLINES[plan.code] || plan.description
  end

  # "R$ 47,99" / "R$ 0"
  def plan_price_label(plan)
    cents = plan.price_cents.to_i
    return "R$ 0" if cents.zero?

    number_to_currency(cents / 100.0, unit: "R$ ", separator: ",", delimiter: ".", format: "%u%n")
  end

  def plan_page_perk?(plan, key)
    return plan.code == "gold" if key == :soon

    (plan.features || {})[key] == true
  end

  # Botão do rodapé do card: [:texto, rótulo] (contorno, sem ação) ou [:checkout, rótulo]
  def plan_page_cta(plan, user)
    current_plan = user&.plan

    if current_plan && plan.id == current_plan.id
      if user.premium_until.present? && user.premium_until.future? && !plan.price_cents.to_i.zero?
        [ :text, "Ativo até #{user.premium_until.strftime('%d/%m/%Y')}" ]
      else
        [ :text, "Seu plano atual" ]
      end
    elsif plan.price_cents.to_i.zero?
      [ :text, "Plano gratuito" ]
    elsif current_plan && plan.price_cents.to_i < current_plan.price_cents.to_i
      [ :text, "Incluído no seu plano" ]
    else
      [ :checkout, "Assinar #{plan.name}" ]
    end
  end
end
