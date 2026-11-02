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
    [ "Interação no mapa ilimitada", "likes_right_unlimited" ],
    [ "Lista de quem curtiu você",   "see_who_liked_me" ],
    [ "Lista de quem você curtiu",   "see_who_i_liked" ],
    [ "Mensagens ilimitadas",        "unlimited_messages" ],
    [ "Modo oculto",                 "allow_invisible" ],
    [ "Não mostrar minha idade",     nil ]
  ].freeze

  # Editar Perfil — chips de "Sobre você" (rótulo => valor gravado). "Não Binário"
  # continua com B maiúsculo no banco: é o valor que o onboarding e o filtro do mapa usam.
  PROFILE_GENDER_OPTIONS = [
    [ "Homem", "Homem" ], [ "Mulher", "Mulher" ], [ "Não binário", "Não Binário" ], [ "Outro", "Outro" ]
  ].freeze

  PROFILE_INTERESTED_IN_OPTIONS = [ [ "Homens", "Homem" ], [ "Mulheres", "Mulher" ], [ "Todos", "Todos" ] ].freeze

  BRAZILIAN_STATES = [
    [ "Acre", "AC" ], [ "Alagoas", "AL" ], [ "Amapá", "AP" ], [ "Amazonas", "AM" ], [ "Bahia", "BA" ],
    [ "Ceará", "CE" ], [ "Distrito Federal", "DF" ], [ "Espírito Santo", "ES" ], [ "Goiás", "GO" ],
    [ "Maranhão", "MA" ], [ "Mato Grosso", "MT" ], [ "Mato Grosso do Sul", "MS" ], [ "Minas Gerais", "MG" ],
    [ "Pará", "PA" ], [ "Paraíba", "PB" ], [ "Paraná", "PR" ], [ "Pernambuco", "PE" ], [ "Piauí", "PI" ],
    [ "Rio de Janeiro", "RJ" ], [ "Rio Grande do Norte", "RN" ], [ "Rio Grande do Sul", "RS" ],
    [ "Rondônia", "RO" ], [ "Roraima", "RR" ], [ "Santa Catarina", "SC" ], [ "São Paulo", "SP" ],
    [ "Sergipe", "SE" ], [ "Tocantins", "TO" ]
  ].freeze

  # Sugestões de interesses (aparecem as 4 primeiras que a pessoa ainda não escolheu)
  INTEREST_SUGGESTIONS = [
    "Viagens", "Música ao vivo", "Carnaval", "Futebol", "Praia", "Culinária", "Fitness",
    "Cinema", "Séries", "Barzinho", "Trilhas", "Pets"
  ].freeze
  INTEREST_SUGGESTIONS_SHOWN = 4

  VERIFICATION_REJECTION_REASONS = {
    "no_face_in_selfie"          => "Nenhum rosto foi identificado na selfie.",
    "explicit_content"           => "Uma das imagens contém conteúdo inapropriado.",
    "name_not_found_in_document" => "Não conseguimos ler o seu nome no documento enviado.",
    "face_mismatch"              => "O rosto da selfie não corresponde ao documento.",
    "api_error"                  => "Ocorreu um erro ao processar os documentos.",
    "no_face_detected"           => "Nenhum rosto foi identificado na foto.",
    "name_not_found_in_photo"    => "Não conseguimos ler o seu nome na imagem."
  }.freeze

  # :verified, :pending (em análise), :rejected (recusada) ou :none (nunca enviou)
  def profile_verification_state(user)
    if user.verified? then :verified
    elsif %w[pending manual_review].include?(user.ai_moderation_status) then :pending
    elsif user.ai_moderation_status == "rejected" then :rejected
    else :none
    end
  end

  def verification_rejection_reason(user)
    VERIFICATION_REJECTION_REASONS.fetch(user.ai_moderation_details&.dig("reason").to_s,
                                         "Seus documentos não puderam ser aprovados.")
  end

  # Pendências de "Como deixar seu perfil melhor" (Pré-visualizar) => âncora do
  # campo na aba Editar. Fotos e verificação aparecem sempre (feitas ou não).
  PROFILE_PREVIEW_TODOS = [
    [ :interested_in, "Escolha quem você quer conhecer", "pe-interested-in" ],
    [ :gender,        "Informe seu gênero",              "pe-gender" ],
    [ :bio,           "Escreva uma bio",                 "pe-bio" ],
    [ :hobbies,       "Adicione seus interesses",        "pe-interesses" ],
    [ :city,          "Informe sua cidade",              "pe-local" ]
  ].freeze

  # [{ done:, text:, anchor: (campo em Editar) ou link: + link_label: }]
  def profile_preview_tips(user, photos_count)
    photos =
      if photos_count >= 6
        { done: true, text: "6 fotos adicionadas" }
      else
        { done: false, text: "#{photos_count} de 6 fotos adicionadas", anchor: "pe-fotos" }
      end

    verification =
      case profile_verification_state(user)
      when :verified then { done: true, text: "Identidade verificada" }
      when :pending  then { done: false, text: "Verificação de identidade em análise" }
      else { done: false, text: "Verifique sua identidade", link: verification_path, link_label: "Verificar" }
      end

    checks = user.profile_completion_checks
    todos  = PROFILE_PREVIEW_TODOS.reject { |key, _text, _anchor| checks[key] }
                                  .map { |_key, text, anchor| { done: false, text: text, anchor: anchor } }
    [ photos, verification, *todos ]
  end

  def interest_suggestions(user)
    chosen = user.hobbies_list.map { |hobby| hobby.strip.downcase }
    INTEREST_SUGGESTIONS.reject { |suggestion| chosen.include?(suggestion.downcase) }
  end

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
