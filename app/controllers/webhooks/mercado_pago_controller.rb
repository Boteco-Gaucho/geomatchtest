require "openssl"

module Webhooks
  class MercadoPagoController < ActionController::Base
    protect_from_forgery with: :null_session

    def create
      payload_hash = parsed_payload

      event = WebhookEvent.create!(
        source: "mercadopago",
        external_id: extract_external_id(payload_hash),
        topic: params[:type].presence || params[:topic].presence || payload_hash["type"] || payload_hash["topic"],
        action: params[:action].presence || payload_hash["action"],
        payload: payload_hash,
        status: "pending",
        attempts: 0
      )

      ::MercadoPago::WebhookService.call(event: event)

      render json: { id: event.id }, status: :accepted
    rescue JSON::ParserError
      render json: { error: "invalid_json" }, status: :bad_request
    rescue MercadoPagoSignatureError
      render json: { error: "invalid_signature" }, status: :unauthorized
    end

    private

    class MercadoPagoSignatureError < StandardError; end

    def parsed_payload
      raw = request.raw_post.to_s
      return {} if raw.blank?
      JSON.parse(raw)
    end

    def extract_external_id(payload_hash)
      payload_hash.dig("data", "id")&.to_s ||
        payload_hash["id"]&.to_s ||
        params[:data_id]&.to_s
    end
  end
end


