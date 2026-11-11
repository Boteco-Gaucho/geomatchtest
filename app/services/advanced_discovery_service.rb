# app/services/advanced_discovery_service.rb
class AdvancedDiscoveryService
  def initialize(user)
    @user = user
  end

  # Agora aceita um hash de opções (filters)
  def find_next_eligible_user(excluded_user_ids, filters = {})
    # Define padrões se os filtros não vierem: Distância 500km (se nil), Idade 18-100
    search_distance = filters[:distance].to_i > 0 ? filters[:distance].to_i : 500
    min_age = filters[:min_age]
    max_age = filters[:max_age]

    # 1. Constrói a query base: Localização (Dinâmica) e Exclusão
    # Usamos search_distance aqui em vez do 10 fixo
    # User.visible: regra de discovery — usuários em modo invisível não aparecem
    base_query = User.visible
                     .near([@user.latitude, @user.longitude], search_distance)
                     .where.not(id: @user.id)
                     .where.not(id: excluded_user_ids)

    # 2. Aplica Filtro de Idade (NOVO)
    if min_age.present? && max_age.present?
      base_query = base_query.filter_by_age(min_age, max_age)
    end

    # 3. Aplica Filtro de Interesse (Gênero) existente
    interested_in = @user.interested_in
    generic_options = ["Outro", "Não-binário", "Prefiro não dizer", "Mulher", "Homem"]

    if interested_in.present? && !generic_options.include?(interested_in)
      base_query = base_query.where(gender: interested_in)
    end

    # 4. Carrega para memória
    base_users = base_query.to_a

    return nil, nil if base_users.empty?

    # 5. Prioridade geográfica em camadas:
    #    1ª) mesma cidade do usuário
    #    2ª) outras cidades do mesmo estado (quando a cidade esgotar)
    #    3ª) outros estados (quando o estado esgotar)
    # "Esgotar" acontece naturalmente: perfis já curtidos/rejeitados chegam em
    # excluded_user_ids e saem do pool, fazendo a busca descer de camada.
    next_user = pick_by_location_tier(base_users)

    if next_user
      distance = Geocoder::Calculations.distance_between(
        [@user.latitude, @user.longitude],
        [next_user.latitude, next_user.longitude]
      ).round(1)
      return next_user, distance
    else
      return nil, nil
    end
  end

  private

  # Percorre as camadas de localização em ordem e sorteia dentro da primeira
  # camada que tiver candidatos. Usuário sem cidade/estado cadastrado cai
  # direto na camada geral (comportamento anterior).
  def pick_by_location_tier(users)
    city  = @user.city.to_s.strip
    state = @user.state.to_s.strip

    tiers = []
    tiers << ->(u) { same_text?(u.city, city) && same_text?(u.state, state) } if city.present? && state.present?
    tiers << ->(u) { same_text?(u.state, state) }                             if state.present?
    tiers << ->(_) { true }

    tiers.each do |tier|
      candidates = users.select(&tier)
      chosen = pick_with_hobby_preference(candidates)
      return chosen if chosen
    end

    nil
  end

  # Dentro da camada, mantém a preferência existente: quem tem hobbies em comum
  # vem primeiro; sem ninguém em comum, qualquer um da camada serve.
  def pick_with_hobby_preference(candidates)
    return nil if candidates.empty?

    user_hobbies = @user.hobbies_list
    if user_hobbies.any?
      with_common = candidates.select { |u| (u.hobbies_list & user_hobbies).any? }
      return with_common.sample if with_common.any?
    end

    candidates.sample
  end

  # Comparação tolerante: ignora maiúsculas/minúsculas e espaços nas pontas
  # (Geocoder pode gravar "Itabuna" / "itabuna " dependendo da fonte).
  def same_text?(a, b)
    a.to_s.strip.casecmp?(b.to_s.strip)
  end
end
