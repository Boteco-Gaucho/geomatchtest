# frozen_string_literal: true

module Api
  module V1
    module Admin
      # GET    /api/v1/admin/moderation                    → lista pendentes
      # PATCH  /api/v1/admin/moderation/:id/verify_user   → aprova verificação
      # PATCH  /api/v1/admin/moderation/:id/reject_photo  → recusa foto
      # PATCH  /api/v1/admin/moderation/:id/ban_user      → bane conta
      class ModerationController < BaseController
        PAGE_SIZE = 20

        # Lista pendentes, verificados e recusados
        def index
          pending_users  = pending_scope.page(params[:page]).per(PAGE_SIZE)
          verified_users = verified_scope.page(params[:page]).per(PAGE_SIZE)
          rejected_users = rejected_scope.page(params[:page]).per(PAGE_SIZE)

          Rails.logger.debug "[Moderation#index] Pendentes: #{pending_scope.count} | Verificados: #{verified_scope.count} | Recusados: #{rejected_scope.count}"

          render json: {
            pending:  pending_users.map  { |u| serialize(u) },
            verified: verified_users.map { |u| serialize(u) },
            rejected: rejected_users.map { |u| serialize(u) },
            pagination: {
              current_page:  pending_users.current_page,
              total_pages:   pending_users.total_pages,
              total_count:   pending_users.total_count
            }
          }
        rescue => e
          Rails.logger.error "[Moderation#index] Erro: #{e.message}"
          render json: { pending: [], verified: [], rejected: [], pagination: { current_page: 1, total_pages: 0, total_count: 0 } }, status: :ok
        end

        # Marca usuário como verificado e remove a foto de verificação
        def verify_user
          user = User.find(params[:id])
          user.update!(verified: true)
          user.verification_photo.purge_later if user.verification_photo.attached?
          render json: { id: user.id, verified: true, message: 'Usuário verificado com sucesso.' }
        rescue ActiveRecord::RecordNotFound
          api_not_found('Usuário não encontrado.')
        rescue ActiveRecord::RecordInvalid => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        # Remove os documentos KYC (sem verificar)
        def reject_photo
          user = User.find(params[:id])
          reason = params[:reason].presence || 'Documentos não correspondem ao perfil.'
          purge_kyc_documents(user)
          Rails.logger.info "[MODERATION] Documentos recusados para User##{user.id} (#{user.email}). Motivo: #{reason}"
          render json: { id: user.id, message: 'Documentos removidos.' }
        rescue ActiveRecord::RecordNotFound
          api_not_found('Usuário não encontrado.')
        end

        # Reenfileira documentos para reanálise pela IA
        def reanalyze
          user = User.find(params[:id])

          unless user.document_front.attached? && user.document_back.attached? && user.selfie_with_document.attached?
            return render json: { success: false, error: "Usuário não possui todos os documentos KYC." },
                          status: :unprocessable_entity
          end

          user.update_columns(
            ai_moderation_status:  "pending",
            ai_moderation_score:   nil,
            ai_moderation_details: nil
          )
          AnalyzeVerificationPhotoJob.perform_later(user.id)
          render json: { success: true, message: "Reanálise enfileirada com sucesso." }
        rescue ActiveRecord::RecordNotFound
          api_not_found("Usuário não encontrado.")
        end

        # Reverte a rejeição para o usuário reenviar os documentos
        def undo_rejection
          user = User.find(params[:id])
          user.update_columns(
            ai_moderation_status:  nil,
            ai_moderation_score:   nil,
            ai_moderation_details: nil
          )
          Rails.logger.info "[MODERATION] Rejeição revertida para User##{user.id} (#{user.email})."
          render json: { id: user.id, message: 'Rejeição revertida. O usuário pode reenviar os documentos.' }
        rescue ActiveRecord::RecordNotFound
          api_not_found('Usuário não encontrado.')
        end

        # Bane a conta e remove os documentos
        def ban_user
          user = User.find(params[:id])
          return render json: { error: 'Não é possível banir um administrador.' },
                        status: :unprocessable_entity if user.admin?

          user.ban!
          purge_kyc_documents(user)
          render json: { id: user.id, banned: true, message: 'Conta banida e documentos removidos.' }
        rescue ActiveRecord::RecordNotFound
          api_not_found('Usuário não encontrado.')
        end

        private

        def pending_scope
          User.where(verified: false, banned_at: nil)
              .joins(:document_front_attachment)
              .order(created_at: :desc)
        end

        def verified_scope
          User
            .where(verified: true, banned_at: nil)
            .includes(avatar_attachment: :blob)
            .order(updated_at: :desc)
        end

        def rejected_scope
          User
            .where(ai_moderation_status: "rejected", banned_at: nil)
            .includes(avatar_attachment: :blob)
            .order(updated_at: :desc)
        end

        def serialize(user)
          {
            id:                          user.id,
            name:                        user.display_name,
            email:                       user.email,
            created_at:                  user.created_at.iso8601,
            avatar_url:                  blob_path(user.avatar),
            document_front_url:          blob_path(user.document_front),
            document_back_url:           blob_path(user.document_back),
            selfie_with_document_url:    blob_path(user.selfie_with_document),
            ai_moderation_status:        user.ai_moderation_status,
            ai_moderation_score:         user.ai_moderation_score,
            ai_moderation_details:       user.ai_moderation_details
          }
        end

        def blob_path(attachment)
          return nil unless attachment.attached?
          Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
        end

        def purge_kyc_documents(user)
          user.document_front.purge_later          if user.document_front.attached?
          user.document_back.purge_later           if user.document_back.attached?
          user.selfie_with_document.purge_later    if user.selfie_with_document.attached?
        end
      end
    end
  end
end
