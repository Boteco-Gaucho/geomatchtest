# Filtros da tela de início (/lead — a folha "Filtros" de users/lead.html.erb).
#
# Ficam na sessão (session[:lead_filters]) para valer também depois de curtir ou
# rejeitar — antes viviam só na URL e a próxima pessoa vinha com os padrões fixos.
# O AdvancedDiscoveryService recebe #to_discovery.
class LeadFilters
  SESSION_KEY = :lead_filters

  GENDERS = {
    "mulheres"     => { label: "Mulheres",    values: [ "mulher" ] },
    "homens"       => { label: "Homens",      values: [ "homem" ] },
    "nao_binario"  => { label: "Não binário", values: [ "não binário", "nao binario", "não-binário" ] }
  }.freeze

  # Chips do mockup → termos procurados nos interesses do perfil (texto livre, vindo
  # das sugestões de Editar perfil: "Viagens", "Fitness", "Culinária"…). Sem acento.
  INTERESTS = {
    "praia"       => { label: "Praia",       terms: %w[praia] },
    "viagem"      => { label: "Viagem",      terms: %w[viage viaja] },
    "cinema"      => { label: "Cinema",      terms: %w[cinema filme serie] },
    "musica"      => { label: "Música",      terms: %w[music show] },
    "academia"    => { label: "Academia",    terms: %w[academia fitness treino musculacao crossfit] },
    "gastronomia" => { label: "Gastronomia", terms: %w[gastronomia culinaria cozinha comida restaurante] },
    "leitura"     => { label: "Leitura",     terms: %w[leitura livro ler] },
    "balada"      => { label: "Balada",      terms: %w[balada barzinho festa carnaval] }
  }.freeze

  DISTANCE_RANGE = (1..500)
  AGE_RANGE      = (18..99)
  DEFAULT_AGES   = [ 18, 60 ].freeze

  attr_reader :genders, :distance, :expand, :min_age, :max_age, :interests, :online, :verified, :with_bio

  def self.from_session(session, user)
    new(session[SESSION_KEY] || {}, user)
  end

  # params: os campos f[...] da folha de filtros
  def self.from_params(params, user)
    new(params.to_unsafe_h.slice(*%w[genders distance expand min_age max_age interests online verified with_bio]), user)
  end

  def self.defaults(user)
    new({}, user)
  end

  def initialize(data, user)
    data  = (data || {}).to_h.stringify_keys
    @user = user

    @genders   = data.key?("genders") ? clean_keys(data["genders"], GENDERS) : default_genders
    @distance  = clamp(data["distance"], DISTANCE_RANGE, DISTANCE_RANGE.max)
    @expand    = data.key?("expand") ? truthy?(data["expand"]) : true
    @min_age   = clamp(data["min_age"], AGE_RANGE, DEFAULT_AGES[0])
    @max_age   = clamp(data["max_age"], AGE_RANGE, DEFAULT_AGES[1])
    @min_age, @max_age = @max_age, @min_age if @min_age > @max_age
    @interests = clean_keys(data["interests"], INTERESTS)
    @online    = truthy?(data["online"])
    @verified  = truthy?(data["verified"])
    @with_bio  = truthy?(data["with_bio"])
  end

  # Para a sessão (só tipos simples)
  def to_session
    { "genders" => genders, "distance" => distance, "expand" => expand, "min_age" => min_age,
      "max_age" => max_age, "interests" => interests, "online" => online, "verified" => verified,
      "with_bio" => with_bio }
  end

  def to_discovery
    {
      distance: distance, expand: expand, min_age: min_age, max_age: max_age,
      genders: genders.flat_map { |key| GENDERS[key][:values] },
      interest_terms: interests.flat_map { |key| INTERESTS[key][:terms] },
      online: online, verified: verified, with_bio: with_bio
    }
  end

  # Filtros ajustados (diferentes do padrão), um chip para cada: "Mulheres", "18 – 60 anos",
  # "até 80 km", "Praia" / "2 interesses", "Online agora", "Verificados", "Com bio".
  # Aparecem no fim dos perfis (users/_swipe_area) e contam no número do botão de filtros
  # e no selo "N ativos" da folha (filters_controller.js segue os mesmos critérios).
  def active_chips
    base = self.class.defaults(@user)
    chips = []
    if genders.sort != base.genders.sort
      chips << (genders.empty? ? "Todos os gêneros" : genders.map { |key| GENDERS[key][:label] }.join(" e "))
    end
    chips << "#{min_age} – #{max_age} anos" if [ min_age, max_age ] != [ base.min_age, base.max_age ]
    chips << "até #{distance} km" if distance != base.distance
    if interests.size == 1
      chips << INTERESTS[interests.first][:label]
    elsif interests.size > 1
      chips << "#{interests.size} interesses"
    end
    chips << "Online agora" if online
    chips << "Verificados" if verified
    chips << "Com bio" if with_bio
    chips
  end

  def active_count
    active_chips.size
  end

  private

  # "Quero conhecer" do perfil: Mulher → mulheres, Homem → homens, Todos/vazio → todos
  def default_genders
    case @user&.interested_in.to_s.strip.downcase
    when "mulher", "mulheres" then [ "mulheres" ]
    when "homem", "homens"    then [ "homens" ]
    else []
    end
  end

  def clean_keys(values, allowed)
    Array(values).map(&:to_s).select { |key| allowed.key?(key) }.uniq
  end

  def clamp(value, range, default)
    number = Integer(value.to_s, exception: false)
    number ? number.clamp(range.min, range.max) : default
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value) == true
  end
end
