class CheckoutController < ApplicationController
  before_action :authenticate_user!
  before_action :set_plan, only: [:create]

  def create
    payment = MercadoPago::CheckoutProService.call(user: current_user, plan: @plan)
    respond_to do |format|
      format.html do
        redirect_to payment.mercado_pago_checkout_url, allow_other_host: true
      end

      format.json do
        render json: {
          payment_id: payment.id,
          checkout_url: payment.mercado_pago_checkout_url
        }, status: :created
      end
    end

  # Antes ia para root_path, que redireciona quem está logado para o mapa: o aviso se
  # perdia no segundo redirecionamento e a pessoa caía no mapa sem saber o que houve.
  # Agora volta para /plans com o aviso, e o motivo real (configuração ausente, recusa
  # do Mercado Pago) fica no log.
  rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing
    checkout_failed!("Plano não encontrado. Escolha um plano para continuar.")
  rescue MercadoPago::CheckoutProService::ConfigurationError, MercadoPago::CheckoutProService::ProviderError,
         ActiveRecord::RecordInvalid => e
    Rails.logger.error "[Checkout] Falha ao abrir o pagamento do plano #{params[:plan_id].inspect} " \
                       "para User##{current_user.id}: #{e.class}: #{e.message}"
    checkout_failed!("Não deu para abrir o pagamento agora. Tente de novo em instantes.")
  end

  def create_one_off_message
    amount_cents = Setting.one_off_message_price

    payment = MercadoPago::OneOffMessageService.call(
      user:         current_user,
      amount_cents: amount_cents
    )

    redirect_to payment.checkout_url, allow_other_host: true

  rescue MercadoPago::OneOffMessageService::ConfigurationError,
         MercadoPago::OneOffMessageService::ProviderError => e
    Rails.logger.error "[OneOffMessage] Erro para User##{current_user.id}: #{e.message}"
    redirect_to matches_path, alert: "Não foi possível iniciar o pagamento. Tente novamente."
  end

  private

  def checkout_failed!(message)
    respond_to do |format|
      format.html { redirect_to plans_path, alert: message }
      format.json { render json: { error: message }, status: :unprocessable_entity }
    end
  end

  def set_plan
    @plan = Plan.find(params.require(:plan_id))
  end
end


