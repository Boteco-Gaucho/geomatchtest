class JwtService
  ALGORITHM  = 'HS256'
  SECRET     = Rails.application.secret_key_base
  EXPIRY     = 30.days

  # Gera um token JWT para o payload fornecido.
  # Garante sempre um campo :exp (expiração) e :jti (ID único).
  def self.encode(payload)
    payload = payload.with_indifferent_access
    payload[:exp] ||= EXPIRY.from_now.to_i
    payload[:jti] ||= SecureRandom.uuid

    JWT.encode(payload.to_h, SECRET, ALGORITHM)
  end

  # Decodifica e valida um token.
  # Lança JWT::DecodeError ou JWT::ExpiredSignature em caso de falha.
  def self.decode(token)
    decoded = JWT.decode(token, SECRET, true, { algorithm: ALGORITHM })
    decoded.first.with_indifferent_access
  end
end
