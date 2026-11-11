require "active_support/core_ext/integer/time"

Rails.application.configure do
  # --------------------------
  # URL padrão da aplicação
  # --------------------------
  Rails.application.routes.default_url_options[:host] = "https://geomatch-cvtv.onrender.com"

  # --------------------------
  # Performance e carregamento
  # --------------------------
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # --------------------------
  # Cache
  # --------------------------
  config.action_controller.perform_caching = true
  config.public_file_server.headers = {
    "cache-control" => "public, max-age=#{1.year.to_i}"
  }

  # --------------------------
  # Active Storage (Cloudinary)
  # --------------------------
  config.active_storage.service = :cloudinary

  # --------------------------
  # Logging
  # --------------------------
  config.log_tags = [:request_id]
  config.log_level = :debug

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # --------------------------
  # Healthcheck
  # --------------------------
  config.silence_healthcheck_path = "/up"

  # --------------------------
  # Deprecations
  # --------------------------
  config.active_support.report_deprecations = false

  # --------------------------
  # Cache store
  # --------------------------
  config.cache_store = :solid_cache_store

  # --------------------------
  # Active Job / Solid Queue
  # --------------------------
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # --------------------------
  # Mailer
  # --------------------------
  config.action_mailer.default_url_options = { host: "geomatch-cvtv.onrender.com" }

  # Configurações SMTP para envio de e-mails em produção
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address:              ENV['SMTP_ADDRESS'],
    port:                 ENV['SMTP_PORT'],
    user_name:            ENV['SMTP_USERNAME'],
    password:             ENV['SMTP_PASSWORD'],
    authentication:       'plain',
    enable_starttls_auto: true,
    domain:               'geomatchbr.com' # Substitua pelo seu domínio
  }

  # --------------------------
  # I18n fallback
  # --------------------------
  config.i18n.fallbacks = true

  # --------------------------
  # Schema
  # --------------------------
  config.active_record.dump_schema_after_migration = false

  # --------------------------
  # Logging minimal attributes
  # --------------------------
  config.active_record.attributes_for_inspect = [:id]

  # =======================================================
  # ACTION CABLE — Solid Cable + Render (configuração fixa)
  # =======================================================

  # URL usada pelo frontend
  config.action_cable.url = ENV["CABLE_URL"] || "wss://geomatch-cvtv.onrender.com/cable"

  # Aceita conexões apenas do domínio da aplicação
  config.action_cable.allowed_request_origins = [
    "https://geomatch-cvtv.onrender.com",
    %r{https://geomatch-cvtv\.onrender\.com/?}
  ]

  # Caminho onde o cable está montado
  config.action_cable.mount_path = "/cable"

  # Força HTTPS para não quebrar o WebSocket
  config.force_ssl = true
end
