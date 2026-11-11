class AnalyzeVerificationPhotoJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)

    unless user.document_front.attached? && user.document_back.attached? && user.selfie_with_document.attached?
      Rails.logger.info "[AnalyzeVerificationPhotoJob] User##{user_id} não possui todas as fotos KYC. Pulando."
      return
    end

    result = ImageModerationService.analyze_kyc(
      document_front_url: user.document_front.url,
      document_back_url:  user.document_back.url,
      selfie_url:         user.selfie_with_document.url,
      expected_name:      user.display_name
    )

    user.update_columns(
      ai_moderation_status:  result[:status].to_s,
      ai_moderation_score:   result[:score],
      ai_moderation_details: result[:details]
    )

    Rails.logger.info "[AnalyzeVerificationPhotoJob] User##{user_id} moderado: status=#{result[:status]} score=#{result[:score]}"

    case result[:status]
    when :approved
      user.update(verified: true)
      Rails.logger.info "[AnalyzeVerificationPhotoJob] User##{user_id} verificado automaticamente pela IA."
    when :rejected
      user.document_front.purge
      user.document_back.purge
      user.selfie_with_document.purge
      UserMailer.verification_rejected(user).deliver_later
      Rails.logger.info "[AnalyzeVerificationPhotoJob] User##{user_id} documentos removidos pela IA (KYC rejeitado)."
    when :manual_review
      Rails.logger.info "[AnalyzeVerificationPhotoJob] User##{user_id} encaminhado para revisão manual."
    end

  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "[AnalyzeVerificationPhotoJob] User##{user_id} não encontrado. Job ignorado."

  rescue StandardError => e
    Rails.logger.error "[AnalyzeVerificationPhotoJob] Erro ao moderar User##{user_id}: #{e.class} — #{e.message}"

    User.find_by(id: user_id)&.update_columns(
      ai_moderation_status:  "error",
      ai_moderation_details: { error: e.class.to_s, message: e.message }
    )
  end
end
