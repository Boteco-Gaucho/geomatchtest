class PlansController < ApplicationController
  before_action :authenticate_user!, except: [:index]

  def index
    @plans = Plan.where(active: true).order(price_cents: :asc)
  end
  def modal
    # Captura o tipo de bloqueio enviado pelo JavaScript (ex: 'invisible')
    @feature_type = params[:type]

    # Renderiza apenas o HTML do modal, sem o cabeçalho e rodapé do site
    render layout: false
  end
end


