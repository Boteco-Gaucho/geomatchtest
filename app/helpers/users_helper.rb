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
    [ "Não mostrar minha idade",     :hide_age ] # Plan#allows_hide_age?
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

  # Perfil de outra pessoa (/users/:id) — pílulas de "Informações"
  PROFILE_SEEKING_LABELS = {
    "homem" => "homens", "homens" => "homens",
    "mulher" => "mulheres", "mulheres" => "mulheres",
    "todos" => "todo mundo", "todas" => "todo mundo", "ambos" => "todo mundo"
  }.freeze

  # "Homem", "Não binário"… (o banco guarda "Não Binário" com B maiúsculo)
  # Artigo antes do nome ("na resposta do Luan"), pelo gênero que a pessoa informou no perfil;
  # sem gênero masculino/feminino informado, "de".
  def owner_article(user)
    case user.gender.to_s.downcase
    when "homem"  then "do"
    when "mulher" then "da"
    else "de"
    end
  end

  def profile_gender_label(user)
    value = user.gender.to_s.strip
    return if value.empty?

    PROFILE_GENDER_OPTIONS.find { |_label, saved| saved.casecmp?(value) }&.first || value.capitalize
  end

  # "Quer conhecer mulheres" / "Quer conhecer todo mundo"
  def profile_seeking_label(user)
    value = user.interested_in.to_s.strip
    return if value.empty?

    "Quer conhecer #{PROFILE_SEEKING_LABELS.fetch(value.downcase, value.downcase)}"
  end

  # "Itabuna, BA" — só cidade/estado; o perfil não mostra distância
  def profile_place(user)
    [ user.city, user.state ].compact_blank.join(", ").presence
  end

  # ---------- Perfil: "Em resumo" e "Estilo de vida" (ProfileDetails) ----------
  # [[ícone, rótulo, valor]] só com o que a pessoa informou ("Prefiro não informar" some)
  def profile_summary_rows(user)
    rows = []
    if User.profile_details?
      rows << [ :briefcase, "Profissão", ProfileDetails.occupation_label(user.occupation, user.gender) ]
      edu = user.education_level
      rows << [ :cap, "Escolaridade", ProfileDetails::EDUCATION_LABELS[edu] ]
      rows << [ :ruler, "Altura", ProfileDetails.height_label(user.profile_detail(:height_cm)) ]
      sign = user.profile_detail(:zodiac_sign)
      rows << [ :star, "Signo", (sign if ProfileDetails.informed?(sign)) ]
      langs = Array(user.profile_detail(:languages)).select { |l| ProfileDetails.informed?(l) }
      rows << [ :languages, "Idiomas", langs.join(" · ").presence ]
    end
    rows << [ :pin, "Mora em", profile_place(user) ]
    rows.select { |_icon, _label, value| value.present? }
  end

  def profile_lifestyle_rows(user)
    return [] unless User.profile_details?

    single = ->(field, options) do
      value = user.profile_detail(field)
      ProfileDetails.informed?(value) ? ProfileDetails.third_person(options, value) : nil
    end
    exercise = Array(user.profile_detail(:exercise)).select { |v| ProfileDetails.informed?(v) }
                                                    .map { |v| ProfileDetails.third_person(ProfileDetails::EXERCISE, v) }
    [
      [ :glass,   "Bebida",          single.(:drinking, ProfileDetails::DRINKING) ],
      [ :smoke,   "Cigarro",         single.(:smoking, ProfileDetails::SMOKING) ],
      [ :run,     "Atividade física", exercise.join(" · ").presence ],
      [ :paw,     "Pets",            single.(:pets, ProfileDetails::PETS) ],
      [ :kid,     "Filhos",          single.(:kids, ProfileDetails::KIDS) ]
    ].select { |_icon, _label, value| value.present? }
  end

  def profile_looking_for(user)
    value = user.profile_detail(:looking_for)
    value if User.profile_details? && ProfileDetails.informed?(value)
  end

  def profile_favorite_places(user)
    return [] unless User.profile_details?

    Array(user.profile_detail(:favorite_places)).select { |p| ProfileDetails.informed?(p) }
  end

  PROFILE_ROW_ICONS = {
    briefcase: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18"/>',
    cap:       '<path d="M22 10 12 5 2 10l10 5 10-5z"/><path d="M6 12v5c3 2 9 2 12 0v-5"/>',
    ruler:     '<path d="m3 17 14-14 4 4L7 21z"/><path d="m7 13 2 2M10 10l2 2M13 7l2 2"/>',
    star:      '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
    languages: '<path d="M4 5h9M8.5 3v2M6 5c0 4 3 7 6 8M11 5c0 4-3 7-7 9"/><path d="m13 21 4-9 4 9M14.5 18h5"/>',
    pin:       '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0z"/><circle cx="12" cy="10" r="3"/>',
    glass:     '<path d="M8 22h8M12 15v7M6 3h12l-1 7a5 5 0 0 1-10 0z"/>',
    smoke:     '<rect x="2" y="15" width="16" height="4" rx="1"/><path d="M21 15v4M18 7c0-2 2-2 2-4M14 7c0-2 2-2 2-4"/>',
    run:       '<path d="M6.5 6.5h11M6.5 17.5h11M3 9v6M21 9v6M6.5 6.5v11M17.5 6.5v11"/>',
    paw:       '<circle cx="5.5" cy="10" r="2"/><circle cx="9.5" cy="5.5" r="2"/><circle cx="14.5" cy="5.5" r="2"/><circle cx="18.5" cy="10" r="2"/><path d="M12 12c-3 0-6 3.5-6 6 0 1.7 1.3 3 3 3 1 0 2-.7 3-.7s2 .7 3 .7c1.7 0 3-1.3 3-3 0-2.5-3-6-6-6z"/>',
    kid:       '<circle cx="12" cy="6" r="3"/><path d="M8 21v-5l-2-3 3-3h6l3 3-2 3v5M10 21v-4h4v4"/>'
  }.freeze

  def profile_row_icon(name)
    content_tag(:svg, PROFILE_ROW_ICONS.fetch(name).html_safe, viewBox: "0 0 24 24", "aria-hidden": "true")
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
    return plan.present? && plan.allows_hide_age? if key == :hide_age

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
