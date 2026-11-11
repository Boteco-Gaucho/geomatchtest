# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Ponto de entrada após a resposta do Google.
  def google_oauth2
    auth = request.env["omniauth.auth"]

    # --- Caso 1: Usuário já tem Google vinculado (provider + uid) ---
    @user = User.from_omniauth(auth)

    # --- Caso 2: Usuário existe com este e-mail (vincular conta) ---
    if @user.nil?
      @user = User.find_by(email: auth.info.email)
      @user&.update_columns(provider: auth.provider, uid: auth.uid)
    end

    if @user
      handle_existing_user
    else
      handle_new_user(auth)
    end
  end

  def failure
    redirect_to new_user_session_path,
      alert: "Autenticação com Google falhou. Por favor, tente novamente."
  end

  private

  def handle_existing_user
    if @user.banned?
      redirect_to new_user_session_path,
        alert: "Sua conta foi suspensa. Entre em contato com o suporte."
      return
    end

    sign_in_and_redirect @user, event: :authentication
    set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
  end

  def handle_new_user(auth)
    # Salva apenas os dados do Google na sessão — não cria o usuário ainda.
    # O usuário será criado após preencher os campos obrigatórios no cadastro.
    session["devise.google_data"] = {
      email:    auth.info.email,
      name:     auth.info.name,
      provider: auth.provider,
      uid:      auth.uid
    }

    redirect_to new_user_registration_url,
      notice: "Olá! Preencha as informações abaixo para concluir seu cadastro com o Google."
  end
end
