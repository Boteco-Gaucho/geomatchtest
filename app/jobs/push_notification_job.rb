require "stringio"

class PushNotificationJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    recipient = message.match.other_user(message.sender)
    return unless recipient
    return if recipient.id == message.sender_id

    title   = message.sender.display_name
    body    = message.content.truncate(80)
    url     = "/matches/#{message.match_id}"
    payload = { title: title, body: body, data: { path: url, app: "GeoMatch" }, tag: "chat-#{message.match_id}" }.to_json

    # Os três canais são completamente independentes — falha em um não afeta os outros.
    send_web_push(recipient, message_id, payload)
    send_apns(recipient, message_id, title, body, url)
    send_fcm(recipient, message_id, title, body, url)
  end

  private

  # ── Canal 1: Web Push (navegadores / PWA) ─────────────────────────
  def send_web_push(recipient, message_id, payload)
    unless ENV["VAPID_PUBLIC_KEY"].present? && ENV["VAPID_PRIVATE_KEY"].present?
      Rails.logger.warn "[WebPush] VAPID keys ausentes — skipping message=#{message_id}"
      return
    end

    subscriptions = recipient.push_subscriptions
    if subscriptions.empty?
      Rails.logger.info "[WebPush] Nenhuma subscription ativa para user=#{recipient.id} message=#{message_id}"
      return
    end

    Rails.logger.info "[WebPush] Disparando para #{subscriptions.size} subscription(s) — message=#{message_id} user=#{recipient.id}"

    vapid = {
      subject:     ENV.fetch("VAPID_SUBJECT", "mailto:contato@geomatch.app"),
      public_key:  ENV["VAPID_PUBLIC_KEY"],
      private_key: ENV["VAPID_PRIVATE_KEY"]
    }

    subscriptions.each do |subscription|
      begin
        ::WebPush.payload_send(
          message:      payload,
          endpoint:     subscription.endpoint,
          p256dh:       subscription.p256dh,
          auth:         subscription.auth,
          vapid:        vapid,
          ssl_timeout:  10,
          open_timeout: 10,
          read_timeout: 10
        )
        Rails.logger.info "[WebPush] Enviado com sucesso — message=#{message_id} subscription=#{subscription.id} user=#{recipient.id}"
      rescue ::WebPush::ExpiredSubscription, ::WebPush::InvalidSubscription => e
        Rails.logger.warn "[WebPush] Subscription inválida/expirada (#{e.class}) — removendo subscription=#{subscription.id}"
        subscription.destroy
      rescue => e
        Rails.logger.error "[WebPush] Erro ao enviar — message=#{message_id} subscription=#{subscription.id} error=#{e.class}: #{e.message}"
      end
    end
  end

  # ── Canal 2: APNs (iOS nativo) ────────────────────────────────────
  def send_apns(recipient, message_id, title, body, url)
    return unless recipient.apns_token.present?

    unless ENV["APNS_KEY_P8"].present? && ENV["APNS_KEY_ID"].present? && ENV["APNS_TEAM_ID"].present?
      Rails.logger.warn "[APNs] Variáveis de ambiente ausentes — skipping message=#{message_id}"
      return
    end

    connection = nil
    begin
      raw_env = ENV.fetch("APNS_KEY_P8", "")

      # Remove cabeçalhos e qualquer espaço/quebra de linha do valor da ENV
      pure_base64 = raw_env
        .gsub(/-----BEGIN PRIVATE KEY-----/, "")
        .gsub(/-----END PRIVATE KEY-----/, "")
        .gsub(/\s+/, "")

      # Reconstrói PEM estrito exigido pelo OpenSSL (linhas de 64 chars)
      formatted_key = "-----BEGIN PRIVATE KEY-----\n" \
                      "#{pure_base64.scan(/.{1,64}/).join("\n")}\n" \
                      "-----END PRIVATE KEY-----\n"

      p8_key = StringIO.new(formatted_key)

      connection_options = {
        auth_method: :token,
        cert_path:   p8_key,
        key_id:      ENV.fetch("APNS_KEY_ID"),
        team_id:     ENV.fetch("APNS_TEAM_ID")
      }

      connection = if ENV.fetch("APNS_ENV", "production") == "development"
                     Apnotic::Connection.development(connection_options)
                   else
                     Apnotic::Connection.new(connection_options)
                   end

      notification               = Apnotic::Notification.new(recipient.apns_token)
      notification.alert         = { title: title, body: body }
      notification.sound         = "default"  # toca som padrão e vibra no iOS
      notification.push_type     = "alert"    # apns-push-type: alert — obrigatório iOS 13+
      notification.priority      = 10         # entrega imediata; acorda o dispositivo
      notification.custom_payload = { url: url }
      notification.topic         = ENV.fetch("APNS_TOPIC", "br.com.geomatch.app")

      response = connection.push(notification)

      if response&.ok?
        Rails.logger.info "[APNs] Enviado com sucesso — message=#{message_id} recipient=#{recipient.id}"
      else
        Rails.logger.error "[APNs] Falha na entrega — message=#{message_id} status=#{response&.status} body=#{response&.body}"
      end
    rescue => e
      Rails.logger.error "[APNs] Erro — message=#{message_id} error=#{e.class}: #{e.message}"
    ensure
      connection&.close
    end
  end

  # ── Canal 3: FCM (Firebase Cloud Messaging — Android nativo) ──────
  def send_fcm(recipient, message_id, title, body, url)
    return unless recipient.fcm_token.present?

    unless ENV["FCM_PROJECT_ID"].present?
      Rails.logger.warn "[FCM] FCM_PROJECT_ID ausente — skipping message=#{message_id}"
      return
    end

    begin
      # A gem `fcm` (API HTTP v1) recebe (json_key_path, project_id) nesta ordem.
      fcm = FCM.new("firebase-credentials.json", ENV["FCM_PROJECT_ID"])

      # Payload da v1. O send_v1 já embrulha o hash em { message: ... },
      # portanto passamos apenas o conteúdo interno (token/notification/data).
      message = {
        token:        recipient.fcm_token,
        notification: { title: title, body: body },
        data:         { path: url, url: url }
      }

      response = fcm.send_v1(message)

      if response[:status_code] == 200
        Rails.logger.info "[FCM] Enviado com sucesso — message=#{message_id} recipient=#{recipient.id}"
      else
        Rails.logger.error "[FCM] Falha na entrega — message=#{message_id} status=#{response[:status_code]} body=#{response[:body]}"
      end
    rescue => e
      Rails.logger.error "[FCM] Erro — message=#{message_id} error=#{e.class}: #{e.message}"
    end
  end
end
