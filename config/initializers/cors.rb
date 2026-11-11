# Rack CORS — controla quais origens podem acessar a API.
#
# Variáveis de ambiente:
#   ALLOWED_ORIGINS  → origens permitidas para /api/v1/* (app, mobile)
#                      ex: https://geomatch.app,https://app.geomatch.app
#   ADMIN_ORIGINS    → origens restritas para /api/v1/admin/*
#                      ex: https://admin.geomatch.app

def parse_origins(env_key, *defaults)
  raw = ENV.fetch(env_key, '')
  origins = raw.split(',').map(&:strip).reject(&:blank?)
  origins.concat(defaults)
  origins.uniq
end

app_origins = parse_origins(
  'ALLOWED_ORIGINS',
  'http://localhost:3000',
  'http://localhost:4000'   # Expo / dev front-end
)

admin_origins = parse_origins(
  'ADMIN_ORIGINS',
  'http://localhost:3000',
  'http://localhost:5173'   # Vite admin dev
)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # --- Painel Admin: lista de origens restrita e separada ---
  allow do
    origins(*admin_origins)

    resource '/api/v1/admin/*',
      headers:     :any,
      methods:     %i[get post patch delete options head],
      expose:      ['Authorization'],
      max_age:     300,
      credentials: false
  end

  # --- API pública v1: app mobile e web ---
  allow do
    origins(*app_origins)

    resource '/api/*',
      headers:     :any,
      methods:     %i[get post put patch delete options head],
      expose:      ['Authorization'],
      max_age:     600,
      credentials: false
  end
end
