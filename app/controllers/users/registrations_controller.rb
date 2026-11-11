# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  # Disponibiliza @from_google para a view saber se deve travar o campo de e-mail
  # e esconder os campos de senha (usuário pode defini-los depois via "Esqueci senha").
  before_action :set_google_session_flag

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

  def set_google_session_flag
    @from_google = session["devise.google_data"].present?
  end
end
