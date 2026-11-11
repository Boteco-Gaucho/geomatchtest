class UserMailer < ApplicationMailer
  REJECTION_REASONS = {
    "no_face_in_selfie"           => "Nenhum rosto foi identificado na sua selfie com o documento. Certifique-se de que seu rosto esteja claramente visível.",
    "explicit_content"            => "Uma das imagens enviadas contém conteúdo inapropriado e não pôde ser aceita.",
    "name_not_found_in_document"  => "Seu nome não foi encontrado no documento enviado. Verifique se a frente e o verso do documento estão legíveis.",
    "face_mismatch"               => "O rosto da selfie não corresponde ao rosto no documento. Certifique-se de que a selfie e o documento são seus.",
    "api_error"                   => "Ocorreu um erro ao processar seus documentos. Por favor, tente novamente.",
    # legado — mantido para registros anteriores
    "no_face_detected"            => "Nenhum rosto foi identificado na foto enviada.",
    "name_not_found_in_photo"     => "Seu nome não foi encontrado na foto de verificação."
  }.freeze

  def verification_rejected(user)
    @user             = user
    @rejection_reason = friendly_reason(user.ai_moderation_details)
    mail(to: user.email, subject: "Seus documentos de verificação não foram aprovados — GeoMatch")
  end

  private

  def friendly_reason(details)
    return "Motivo não especificado." if details.blank?

    raw_reason = details.is_a?(Hash) ? (details["reason"] || details[:reason]).to_s : ""
    REJECTION_REASONS.fetch(raw_reason, "Motivo não especificado.")
  end
end
