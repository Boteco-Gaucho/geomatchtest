class Admin::CouponsController < Admin::BaseController
  before_action :set_coupon, only: [:show, :edit, :update, :destroy]

  def index
    @coupons = Coupon.order(created_at: :desc)
  end

  def show
  end

  def new
    @coupon = Coupon.new(active: true, discount_type: 'free_access')
  end

  def create
    @coupon = Coupon.new(coupon_params)

    if @coupon.save
      redirect_to admin_coupon_path(@coupon), notice: 'Cupom criado com sucesso.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @coupon.update(coupon_params)
      redirect_to admin_coupon_path(@coupon), notice: 'Cupom atualizado com sucesso.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @coupon.destroy
    redirect_to admin_coupons_path, notice: 'Cupom excluído com sucesso.'
  end

  private

  def set_coupon
    @coupon = Coupon.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_coupons_path, alert: 'Cupom não encontrado.'
  end

  def coupon_params
    permitted = params.require(:coupon).permit(
      :code, :description, :discount_type, :duration_days,
      :usage_limit, :expires_at, :active, :plan_codes
    )

    # O form envia plan_codes como string separada por vírgula (ex: "plus,gold");
    # o banco espera um array jsonb.
    if permitted.key?(:plan_codes)
      permitted[:plan_codes] = permitted[:plan_codes].to_s.split(',').map(&:strip).reject(&:blank?)
    end

    # Normaliza o código em maiúsculas — User#apply_coupon busca com .upcase,
    # então um cupom salvo em minúsculas nunca seria encontrado.
    permitted[:code] = permitted[:code].to_s.strip.upcase if permitted[:code].present?

    permitted
  end
end
