# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  # Disponibiliza @from_google para a view saber se deve travar o campo de e-mail
  # e esconder os campos de senha (usuário pode defini-los depois via "Esqueci senha").
  before_action :set_google_session_flag
  before_action :normalize_phone, only: :create

  # POST /users — após cadastro bem-sucedido, limpa os dados do Google da sessão.
  def create
    super do |resource|
      session.delete("devise.google_data") if resource.persisted?
    end
  end

  # Novos usuários vão para onboarding antes de entrar no app
  def after_sign_up_path_for(_resource)
    onboarding_path
  end

  def after_inactive_sign_up_path_for(_resource)
    onboarding_path
  end

  private

  # Celular da tela Criar conta: o campo traz só "(71) 99999-9999" (o +55 fica fixo ao
  # lado) — grava +55 com DDD e número, só dígitos
  def normalize_phone
    phone = params.dig(:user, :phone)
    return if phone.blank?

    digits = phone.to_s.gsub(/\D/, "")
    digits = digits.delete_prefix("55") if digits.length > 11
    params[:user][:phone] = "+55#{digits}"
  end

  def set_google_session_flag
    @from_google = session["devise.google_data"].present?
  end
end
