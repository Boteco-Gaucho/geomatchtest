class PlansController < ApplicationController
  before_action :authenticate_user!, except: [ :index ]

  def index
    @plans = Plan.where(active: true).order(price_cents: :asc)
  end

  # Modal de upgrade para o Gold (HTML injetado por JS; ver plans/modal.html.erb)
  def modal
    # Tipo de bloqueio enviado pelo JavaScript (ex.: 'invisible' = modo oculto)
    @feature_type = params[:type]
    # "Assinar Gold" vai direto ao checkout; sem plano Gold ativo, o botão leva a /plans
    @gold_plan = Plan.where(active: true).find_by(code: "gold")

    # Só o HTML do modal, sem o cabeçalho e o rodapé do site
    render layout: false
  end
end
