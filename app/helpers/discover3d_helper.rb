module Discover3dHelper
  # Estados do seletor de "Explorar cidades" (o filtro usa a sigla, como users.state)
  BRAZIL_STATES = {
    "AC" => "Acre", "AL" => "Alagoas", "AP" => "Amapá", "AM" => "Amazonas", "BA" => "Bahia",
    "CE" => "Ceará", "DF" => "Distrito Federal", "ES" => "Espírito Santo", "GO" => "Goiás",
    "MA" => "Maranhão", "MT" => "Mato Grosso", "MS" => "Mato Grosso do Sul", "MG" => "Minas Gerais",
    "PA" => "Pará", "PB" => "Paraíba", "PR" => "Paraná", "PE" => "Pernambuco", "PI" => "Piauí",
    "RJ" => "Rio de Janeiro", "RN" => "Rio Grande do Norte", "RS" => "Rio Grande do Sul",
    "RO" => "Rondônia", "RR" => "Roraima", "SC" => "Santa Catarina", "SP" => "São Paulo",
    "SE" => "Sergipe", "TO" => "Tocantins"
  }.freeze

  # Faixa de capitais (carrossel contínuo), na ordem dos estados — como no mockup
  BRAZIL_CAPITALS = [
    [ "Rio Branco", "AC" ], [ "Maceió", "AL" ], [ "Macapá", "AP" ], [ "Manaus", "AM" ], [ "Salvador", "BA" ],
    [ "Fortaleza", "CE" ], [ "Brasília", "DF" ], [ "Vitória", "ES" ], [ "Goiânia", "GO" ], [ "São Luís", "MA" ],
    [ "Cuiabá", "MT" ], [ "Campo Grande", "MS" ], [ "Belo Horizonte", "MG" ], [ "Belém", "PA" ],
    [ "João Pessoa", "PB" ], [ "Curitiba", "PR" ], [ "Recife", "PE" ], [ "Teresina", "PI" ],
    [ "Rio de Janeiro", "RJ" ], [ "Natal", "RN" ], [ "Porto Alegre", "RS" ], [ "Porto Velho", "RO" ],
    [ "Boa Vista", "RR" ], [ "Florianópolis", "SC" ], [ "São Paulo", "SP" ], [ "Aracaju", "SE" ], [ "Palmas", "TO" ]
  ].freeze

  # "em Itabuna" / "na Bahia"… / "em todo o Brasil"
  def city_search_place(filters)
    return "em #{filters[:city]}" if filters[:city].present?
    return "em #{BRAZIL_STATES.fetch(filters[:state].to_s.upcase, filters[:state])}" if filters[:state].present?

    "em todo o Brasil"
  end
end
