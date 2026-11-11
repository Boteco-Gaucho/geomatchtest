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

  rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing,
    MercadoPago::CheckoutProService::ConfigurationError, MercadoPago::CheckoutProService::ProviderError => e
    respond_to do |format|
      format.html { redirect_to root_path, alert: "Erro ao iniciar pagamento: #{e.message}" }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
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

  def set_plan
    @plan = Plan.find(params.require(:plan_id))
  end
end


