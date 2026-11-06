require "rails_helper"

# Tela /carteira ("Minha Carteira" em Meu Perfil) — pages/mimo_wallet.html.erb.
# O saldo e o extrato também são atualizados pelo wallet_controller.js (JSON de /wallet).
RSpec.describe "Carteira (/carteira)", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let(:user) { create(:user, onboarding_completed: true, plan: free_plan) }

  before { sign_in user, scope: :user }

  def open_wallet
    get "/carteira"
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  it "mostra o mockup: título, card com o saldo disponível, ações, filtros e rodapé" do
    user.create_wallet!(balance_cents: 4_200, pending_withdrawal_cents: 1_000)
    page = open_wallet

    expect(page.at_css(".wl-title").text).to eq("Carteira")
    expect(page.at_css("a.wl-back")["href"]).to eq("/meu-perfil")

    card = page.at_css(".wl-card")
    expect(card["data-controller"]).to eq("balance-visibility")
    expect(card["class"]).not_to include("is-balance-hidden")
    expect(card.at_css(".wl-card-label").text).to eq("Saldo disponível")
    expect(card.at_css(".wl-amount-currency").text).to eq("R$")
    expect(card.at_css('.wl-amount-value[data-wallet-target="balance"]').text).to eq("32,00") # 42 - 10 reservados
    expect(card.at_css(".wl-reserved").text.squish).to eq("R$ 10,00 reservado em saque solicitado")
    expect(card.at_css("a.wl-btn--add")["href"]).to eq("/mimos/depositar")
    expect(card.at_css("a.wl-btn--add").text.squish).to eq("Adicionar")
    expect(card.at_css("button.wl-btn--pix")["data-action"]).to eq("wallet#goToWithdraw")
    expect(card.at_css("button.wl-btn--pix").text.squish).to eq("Sacar via Pix")

    expect(page.at_css(".wl-history-title").text).to eq("Histórico")
    filters = page.css('.wl-filter[data-wallet-target="filter"]')
    expect(filters.map { |f| [ f.text, f["data-filter"], f["aria-pressed"] ] })
      .to eq([ %w[Tudo all true], %w[Entradas in false], %w[Saídas out false] ])
    expect(page.at_css('[data-wallet-target="history"]')).to be_present
    expect(page.at_css(".wl-secure").text.squish).to eq("Pagamentos e saques protegidos pelo Mercado Pago")
    expect(page.at_css(".sidebar")).to be_nil
  end

  it "sem carteira ainda: R$ 0,00 e nada reservado" do
    page = open_wallet

    expect(page.at_css(".wl-amount-value").text).to eq("0,00")
    expect(page.at_css(".wl-reserved")["class"]).not_to include("is-visible")
  end

  it "saldo escondido em Meu Perfil continua escondido aqui (mesmo cookie)" do
    cookies[:hide_wallet_balance] = "1"
    page = open_wallet

    expect(page.at_css(".wl-card")["class"]).to include("is-balance-hidden")
    expect(page.at_css(".wl-eye")["aria-label"]).to eq("Mostrar saldo")
  end
end
