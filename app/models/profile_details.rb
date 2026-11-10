# Opções das seções do Editar perfil ("Lugares que eu curto", "O que você procura",
# "Mais sobre você", "Estilo de vida") e como cada escolha aparece no perfil.
# O banco guarda o texto do chip (como já acontece com o gênero). "Prefiro não informar"
# também é gravado (NOT_INFORMED) e nunca aparece no perfil.
module ProfileDetails
  NOT_INFORMED = "Prefiro não informar"

  FAVORITE_PLACES = %w[Praia Barzinho Shows Pagode Forró Samba Academia Cafeteria Restaurante
                       Balada Eventos Parque Cinema Teatro].freeze
  FAVORITE_PLACES_MAX = 5

  LOOKING_FOR = [ "Relacionamento sério", "Algo sério, mas vamos ver", "Nada sério, mas depende",
                  "Algo casual", "Amizades", "Networking", "Ainda não sei" ].freeze

  # [chip, masculino, feminino] — o perfil mostra conforme o gênero informado
  PROFESSIONS = [
    [ "Advogado(a)", "Advogado", "Advogada" ], [ "Juiz(a)", "Juiz", "Juíza" ],
    [ "Empresário(a)", "Empresário", "Empresária" ], [ "Médico(a)", "Médico", "Médica" ],
    [ "Enfermeiro(a)", "Enfermeiro", "Enfermeira" ], [ "Dentista", "Dentista", "Dentista" ],
    [ "Psicólogo(a)", "Psicólogo", "Psicóloga" ], [ "Engenheiro(a)", "Engenheiro", "Engenheira" ],
    [ "Arquiteto(a)", "Arquiteto", "Arquiteta" ], [ "Professor(a)", "Professor", "Professora" ],
    [ "Policial", "Policial", "Policial" ], [ "Militar", "Militar", "Militar" ],
    [ "Servidor(a) público(a)", "Servidor público", "Servidora pública" ],
    [ "Contador(a)", "Contador", "Contadora" ], [ "Programador(a)", "Programador", "Programadora" ],
    [ "Designer", "Designer", "Designer" ], [ "Vendedor(a)", "Vendedor", "Vendedora" ],
    [ "Comerciante", "Comerciante", "Comerciante" ],
    [ "Corretor(a) de imóveis", "Corretor de imóveis", "Corretora de imóveis" ],
    [ "Motorista", "Motorista", "Motorista" ], [ "Personal trainer", "Personal trainer", "Personal trainer" ],
    [ "Esteticista", "Esteticista", "Esteticista" ], [ "Cabeleireiro(a)", "Cabeleireiro", "Cabeleireira" ],
    [ "Chef de cozinha", "Chef de cozinha", "Chef de cozinha" ], [ "Jornalista", "Jornalista", "Jornalista" ],
    [ "Publicitário(a)", "Publicitário", "Publicitária" ], [ "Fotógrafo(a)", "Fotógrafo", "Fotógrafa" ],
    [ "Influenciador(a)", "Influenciador", "Influenciadora" ], [ "Autônomo(a)", "Autônomo", "Autônoma" ],
    [ "Aposentado(a)", "Aposentado", "Aposentada" ], [ "Outra", "Outra", "Outra" ]
  ].freeze
  OCCUPATION_MAX = 40

  # Escolaridade: chips → enum education_level do User (o cadastro inicial usa os 3 primeiros)
  EDUCATION = [
    [ "Ensino médio", "high_school" ], [ "Graduação", "college_complete" ],
    [ "Pós-graduação", "postgraduate" ], [ "Mestrado ou doutorado", "masters_doctorate" ]
  ].freeze
  EDUCATION_LABELS = {
    "high_school" => "Ensino médio", "college_incomplete" => "Graduação (cursando)",
    "college_complete" => "Graduação", "postgraduate" => "Pós-graduação",
    "masters_doctorate" => "Mestrado ou doutorado"
  }.freeze

  ZODIAC = %w[Áries Touro Gêmeos Câncer Leão Virgem Libra Escorpião Sagitário Capricórnio Aquário Peixes].freeze
  LANGUAGES = %w[Português Inglês Espanhol Francês Italiano Alemão Libras Outro].freeze
  HEIGHTS = (140..210).to_a.freeze

  # [chip (primeira pessoa, no Editar), como aparece no perfil]
  DRINKING = [ [ "Não bebo", "Não bebe" ], [ "Socialmente", "Socialmente" ], [ "Bebo sim", "Bebe" ] ].freeze
  SMOKING  = [ [ "Não fumo", "Não fuma" ], [ "Às vezes", "Fuma às vezes" ], [ "Fumo", "Fuma" ] ].freeze
  EXERCISE = [ [ "Corrida", "Corrida" ], [ "Academia", "Academia" ], [ "Bike", "Bike" ], [ "Futebol", "Futebol" ],
               [ "Vôlei de praia", "Vôlei de praia" ], [ "Natação", "Natação" ], [ "Dança", "Dança" ],
               [ "Yoga", "Yoga" ], [ "Lutas", "Lutas" ], [ "Não pratico", "Não pratica" ] ].freeze
  PETS = [ [ "Tenho cachorro", "Tem cachorro" ], [ "Tenho gato", "Tem gato" ], [ "Amo pets", "Ama pets" ],
           [ "Sem pets", "Sem pets" ] ].freeze
  KIDS = [ [ "Tenho filhos", "Tem filhos" ], [ "Não tenho", "Não tem" ], [ "Quero ter", "Quer ter" ],
           [ "Não quero", "Não quer" ], [ "Ainda não sei", "Ainda não sabe" ] ].freeze

  SINGLE_CHOICES = {
    looking_for: LOOKING_FOR, zodiac_sign: ZODIAC,
    drinking: DRINKING.map(&:first), smoking: SMOKING.map(&:first),
    pets: PETS.map(&:first), kids: KIDS.map(&:first)
  }.freeze
  MULTI_CHOICES = {
    favorite_places: FAVORITE_PLACES, languages: LANGUAGES, exercise: EXERCISE.map(&:first)
  }.freeze
  MULTI_LIMITS = { favorite_places: FAVORITE_PLACES_MAX }.freeze

  COLUMNS = %w[looking_for height_cm zodiac_sign languages favorite_places drinking smoking exercise pets kids].freeze

  module_function

  def informed?(value)
    value.present? && value != NOT_INFORMED
  end

  def third_person(options, value)
    options.to_h.fetch(value, value)
  end

  def height_label(cm)
    cm.to_i.positive? ? format("%.2f m", cm.to_i / 100.0).tr(".", ",") : nil
  end

  # "Advogado(a)" → "Advogado"/"Advogada" pelo gênero; texto livre aparece como foi escrito
  def occupation_label(value, gender)
    return nil unless informed?(value) && value != "Outra"

    row = PROFESSIONS.find { |chip, *_| chip == value }
    return value unless row

    case gender.to_s.downcase
    when "homem"  then row[1]
    when "mulher" then row[2]
    else value
    end
  end
end
