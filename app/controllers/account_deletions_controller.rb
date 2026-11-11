# Página pública de "Exclusão de Conta e Dados" — exigência da Google Play Store.
# Deve ser acessível SEM login por revisores do Google e ex-usuários sem acesso ao app.
class AccountDeletionsController < ApplicationController
  # Não há authenticate_user! global no ApplicationController hoje, mas o skip com
  # raise: false garante que esta página continue 100% pública mesmo que um dia a
  # autenticação global seja adicionada — e não quebra o boot enquanto não existir.
  skip_before_action :authenticate_user!, raise: false

  # Usuário logado com onboarding incompleto também pode acessar (sem redirect).
  skip_before_action :require_onboarding!, raise: false

  def new
    # Sobrescreve o título/descrição padrão do SEO (mecanismo do ApplicationController)
    @seo_tags[:title]       = "GeoMatch - Exclusão de Dados"
    @seo_tags[:description] = "Página oficial para solicitar a exclusão da sua conta e dados do aplicativo GeoMatch."
  end

  def create
    # Honeypot: campo invisível para humanos; se veio preenchido, é bot.
    # Responde como sucesso para não dar sinal ao spammer.
    if params[:website].present?
      redirect_to account_deletion_path, notice: "Solicitação enviada com sucesso!" and return
    end

    name   = params[:name].to_s.strip
    email  = params[:email].to_s.strip
    reason = params[:reason].to_s.strip

    if name.blank? || email.blank?
      redirect_to account_deletion_path, alert: "Por favor, preencha seu nome completo e o email da conta." and return
    end

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      redirect_to account_deletion_path, alert: "Por favor, informe um endereço de email válido." and return
    end

    AccountDeletionMailer.request_deletion(name: name, email: email, reason: reason).deliver_later
    Rails.logger.info "[AccountDeletion] Solicitação enfileirada para #{email}"

    redirect_to account_deletion_path,
                notice: "Solicitação enviada com sucesso! Nossa equipe processará a exclusão da sua conta e dados e você receberá a confirmação no email informado."
  end
end
