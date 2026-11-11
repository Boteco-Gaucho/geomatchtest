class AccountDeletionMailer < ApplicationMailer
  SUPPORT_EMAIL = "suporte@geomatchbr.com".freeze

  # Solicitação pública de exclusão de conta (exigência Google Play).
  # reply_to aponta para o email informado, para o suporte responder direto.
  def request_deletion(name:, email:, reason: nil)
    @name   = name
    @email  = email
    @reason = reason.presence || "Não informado"

    mail(
      to:       SUPPORT_EMAIL,
      reply_to: email,
      subject:  "Solicitação de Exclusão de Conta - GeoMatch"
    )
  end
end
