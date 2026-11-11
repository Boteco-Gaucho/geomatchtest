Geocoder.configure(
  timeout: 5,
  units: :km,
  lookup: :nominatim,
  
  # 1. Força o uso de conexão segura
  use_https: true,

  # 2. IDENTIFICAÇÃO OBRIGATÓRIA (Evita erros 403 e problemas de conexão)
  # Coloque o nome do seu app e um e-mail válido (exigência do Nominatim)
  http_headers: { 
    "User-Agent" => "GeoMatchApp-Felipe (admin@geomatch.com)" 
  }
)