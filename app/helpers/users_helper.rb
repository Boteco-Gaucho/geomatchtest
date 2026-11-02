module UsersHelper
  # Faixas de cor da barra "X% completo" em /meu-perfil:
  #   abaixo de 50% -> vermelho (muito incompleto)
  #   50% a 99%     -> laranja  (pela metade)
  #   100%          -> verde    (tudo certo)
  PROFILE_COMPLETION_HALF = 50

  # Próximo passo sugerido no card "Perfil X% completo", na ordem do mais útil
  # para o menos útil. As chaves são as de User#profile_completion_checks.
  PROFILE_COMPLETION_HINTS = {
    avatar:        "Adicione uma foto sua para quem está por perto te reconhecer.",
    bio:           "Adicione uma bio curta para quem está por perto saber puxar assunto.",
    album_photos:  "Adicione fotos ao álbum para mostrar mais de você.",
    hobbies:       "Conte seus hobbies: é o jeito mais fácil de começar uma conversa.",
    interested_in: "Diga quem você quer conhecer para ver pessoas mais compatíveis.",
    city:          "Informe sua cidade para aparecer para quem está por perto.",
    gender:        "Informe seu gênero para completar o perfil.",
    birthdate:     "Informe sua data de nascimento para mostrar sua idade.",
    username:      "Informe seu nome para as pessoas saberem como te chamar.",
    verified:      "Verifique sua identidade para ganhar o selo azul e passar mais confiança."
  }.freeze

  PROFILE_COMPLETE_HINT = "Tudo certo! Seu perfil está completo e passa confiança para quem está por perto.".freeze

  # Recursos listados nos cards do carrossel "Planos" (rótulo do mockup =>
  # chave em plans.features). nil = recurso que ainda não existe ("Em breve").
  PLAN_PERKS = [
    ["Interação no mapa ilimitada", "likes_right_unlimited"],
    ["Lista de quem curtiu você",   "see_who_liked_me"],
    ["Lista de quem você curtiu",   "see_who_i_liked"],
    ["Mensagens ilimitadas",        "unlimited_messages"],
    ["Modo oculto",                 "allow_invisible"],
    ["Não mostrar minha idade",     nil]
  ].freeze

  def profile_completion_state_class(percentage)
    if percentage >= 100
      "is-complete"
    elsif percentage >= PROFILE_COMPLETION_HALF
      "is-half"
    else
      "is-low"
    end
  end

  # Itens que faltam, na ordem de PROFILE_COMPLETION_HINTS.
  def profile_missing_items(user)
    checks = user.profile_completion_checks
    PROFILE_COMPLETION_HINTS.keys.select { |key| checks.key?(key) && !checks[key] }
  end

  def profile_completion_hint(missing)
    missing.empty? ? PROFILE_COMPLETE_HINT : PROFILE_COMPLETION_HINTS.fetch(missing.first)
  end

  # "Completar perfil" leva direto à verificação quando ela é o próximo passo.
  def profile_completion_path(missing)
    missing.first == :verified ? verification_path : edit_profile_path
  end

  # Nome do plano no perfil — cupom premium em cima do Free aparece como "Premium".
  def profile_plan_name(user)
    return "Premium" if user.premium? && user.plan&.code == "free"

    user.plan&.name || "Free"
  end

  def profile_plan_status(user)
    if user.premium_until.present? && user.premium_until.future?
      "Ativo até #{user.premium_until.strftime('%d/%m/%Y')}"
    elsif user.plan&.code == "free"
      "Plano gratuito"
    else
      "Plano ativo"
    end
  end

  def plan_has_perk?(plan, key)
    key.present? && (plan&.features || {})[key] == true
  end

  # Recursos que o usuário tem de fato. Ver quem curtiu / quem você curtiu também
  # valem com cupom premium; os demais seguem o plano.
  def user_has_perk?(user, key)
    case key
    when "see_who_liked_me" then user.can_see_who_liked_me?
    when "see_who_i_liked"  then user.can_see_who_i_liked?
    when "allow_invisible"  then user.can_use_invisible_mode?
    else plan_has_perk?(user.plan, key)
    end
  end
end
