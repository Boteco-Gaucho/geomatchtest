# frozen_string_literal: true

# Esqueceu a senha? (devise/passwords/new) → "Link enviado!" (devise/passwords/sent).
# O e-mail e a hora do envio ficam na sessão (fora da URL): a tela mostra o e-mail e o
# "Reenviar link em 1:00" conta a partir do último envio, mesmo recarregando.
class Users::PasswordsController < Devise::PasswordsController
  RESEND_AFTER = 60 # segundos até liberar o "Reenviar link"

  def create
    super do |resource|
      if resource.errors.empty?
        session[:password_reset_email]   = resource.email
        session[:password_reset_sent_at] = Time.current.to_i
      end
    end
  end

  # GET /users/password/enviado
  def sent
    @email = session[:password_reset_email]
    return redirect_to(new_user_password_path) if @email.blank?

    elapsed = Time.current.to_i - session[:password_reset_sent_at].to_i
    @resend_in = (RESEND_AFTER - elapsed).clamp(0, RESEND_AFTER)
    flash.delete(:notice) # "Você receberá um e-mail…" — a própria tela já diz isso
  end

  protected

  def after_sending_reset_password_instructions_path_for(_resource_name)
    password_reset_sent_path
  end
end
