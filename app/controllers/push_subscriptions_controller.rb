# app/controllers/push_subscriptions_controller.rb
class PushSubscriptionsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: [:create, :destroy, :create_apns, :create_fcm] # Pode ser necessário para PWA / Hotwire Native

  # FCM (Android nativo): o app envia Bearer JWT, sem cookie de sessão Devise.
  # Autenticação dual isolada nesta action — não afeta create/destroy/create_apns.
  skip_before_action :authenticate_user!,    only: [:create_fcm]
  before_action      :authenticate_for_fcm!, only: [:create_fcm]

  def create
    subscription_params = params.require(:push_subscription).permit(:endpoint, :p256dh, :auth)

    # Busca globalmente: o mesmo endpoint pode estar cadastrado em outro usuário
    # (ex: browser reutilizado). Reatribui ao usuário atual e atualiza as chaves.
    @subscription = PushSubscription.find_or_initialize_by(endpoint: subscription_params[:endpoint])
    @subscription.assign_attributes(subscription_params.merge(user: current_user))

    if @subscription.save
      head :ok
    else
      render json: @subscription.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @subscription = current_user.push_subscriptions.find_by(endpoint: params[:endpoint])
    if @subscription&.destroy
      head :ok
    else
      head :not_found
    end
  end

  # Recebe o device token APNs do app Hotwire Native (iOS) e persiste no usuário.
  # authenticate_user! já garante current_user presente — guard explícito abaixo é defensivo,
  # útil se algum dia trocarmos a auth ou o app tentar registrar antes do login.
  def create_apns
    Rails.logger.info "[APNs] Tentativa de registro para o usuário: #{current_user&.email || 'sem sessão'}"

    return head :unauthorized if current_user.blank?

    token = params[:device_token].to_s.strip
    return head :bad_request if token.blank?

    if current_user.update(apns_token: token)
      Rails.logger.info "[APNs] token registrado user=#{current_user.id} token=#{token.first(8)}…"
      head :ok
    else
      render json: current_user.errors, status: :unprocessable_entity
    end
  end

  # Recebe o registration token FCM (Firebase Cloud Messaging) do app Android
  # e persiste no usuário. Segue o mesmo padrão defensivo do create_apns.
  # Usa @current_fcm_user (setado por authenticate_for_fcm!) — aceita Bearer JWT
  # do app nativo ou sessão Devise como fallback.
  def create_fcm
    Rails.logger.info "[FCM] Tentativa de registro para o usuário: #{@current_fcm_user&.email || 'sem sessão'}"

    return head :unauthorized if @current_fcm_user.blank?

    token = params[:fcm_token].to_s.strip
    return head :bad_request if token.blank?

    if @current_fcm_user.update(fcm_token: token)
      Rails.logger.info "[FCM] token registrado user=#{@current_fcm_user.id} token=#{token.first(8)}…"
      head :ok
    else
      render json: @current_fcm_user.errors, status: :unprocessable_entity
    end
  end

  private

  # Autenticação dual para POST /push_subscriptions/fcm — espelha o padrão de
  # UsersController#authenticate_for_location!.
  #
  # Caminho JWT (app nativo Android):
  #   Header → Authorization: Bearer <token> (gerado por JwtService, HS256)
  #
  # Caminho web (fallback):
  #   Sessão Devise via authenticate_user! padrão
  def authenticate_for_fcm!
    auth_header = request.headers['Authorization']

    if auth_header&.start_with?('Bearer ')
      token             = auth_header.split(' ', 2).last
      payload           = JwtService.decode(token)
      @current_fcm_user = User.find(payload[:sub])
    else
      authenticate_user!
      @current_fcm_user = current_user
    end
  rescue JWT::ExpiredSignature
    render json: { error: 'Token expirado' }, status: :unauthorized
  rescue JWT::DecodeError
    render json: { error: 'Token inválido' }, status: :unauthorized
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Usuário não encontrado' }, status: :unauthorized
  end
end