module PlansHelper
  def render_plan_feature(plan, feature_key)
    features = plan.features || {}
    value = features[feature_key]

    # 1. Filtro de Segurança: Garante que 'likes_right_limit' não apareça visualmente
    return nil if feature_key.to_s == "likes_right_limit"

    # Decide qual renderizador usar baseado na chave (feature)
    case feature_key.to_s
    when "direct_messages"
      render_direct_messages(value)
    when "unlimited_messages", "invisible_mode", "hide_age", "unlimited_map_interaction", "see_who_i_liked", "see_who_liked_me", "likes_right_unlimited", "likes_left_unlimited", "rewind_profile", "search_by_distance"
      # Lógica Booleana: True = Check, False/Nil = Cadeado
      value === true ? render_check : render_lock
    else
      render_generic_feature(value)
    end
  end

  private

  # Renderiza o ícone de Check (✅) - Substitui o antigo render_infinity/generic true
  def render_check
    content_tag(:span, class: "icon-yes", style: "color: #10b981; display: inline-flex; align-items: center; justify-content: center;") do
      tag.svg(width: 24, height: 24, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: 3, stroke_linecap: "round", stroke_linejoin: "round") do
        tag.polyline(points: "20 6 9 17 4 12")
      end
    end
  end

  # Renderiza o ícone de Cadeado (🔒) - Substitui o antigo render_dash
  def render_lock
    content_tag(:span, class: "icon-lock", style: "color: #ef4444; opacity: 0.7; display: inline-flex; align-items: center; justify-content: center;") do
      tag.svg(width: 20, height: 20, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: 2, stroke_linecap: "round", stroke_linejoin: "round") do
        tag.rect(x: 3, y: 11, width: 18, height: 11, rx: 2, ry: 2) +
        tag.path(d: "M7 11V7a5 5 0 0 1 10 0v4")
      end
    end
  end

  def render_direct_messages(dm)
    # Se for nulo ou desabilitado -> Cadeado
    return render_lock if dm.nil? || !dm["enabled"]

    # Caso 1: Ilimitado (Gold) -> Agora é Check (antes era infinito)
    if dm["daily_limit"].nil?
      return render_check
    end

    # Caso 2: Com limite (Plus) -> Mantém o texto informativo
    content_tag(
      :span,
      "#{dm['daily_limit']} por dia",
      class: "text-value",
      style: "font-weight: 500;"
    )
  end

  def render_generic_feature(value)
    if value == true
      render_check
    elsif value == false || value.nil?
      render_lock
    else
      # Texto genérico (números, strings)
      content_tag(:span, value.to_s, class: "text-value")
    end
  end
end