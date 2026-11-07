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

RSpec.describe "Adicionar saldo (/mimos/depositar)", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let(:user) { create(:user, onboarding_completed: true, plan: free_plan) }

  before { sign_in user, scope: :user }

  it "mostra o mockup: R$ 50 escolhido, saldo depois e o botão com o valor" do
    user.create_wallet!(balance_cents: 2_000)
    get "/mimos/depositar"
    page = Nokogiri::HTML(response.body)
    root = page.at_css('[data-controller="wallet"]')

    expect(root["data-wallet-mode-value"]).to eq("deposit")
    expect(root["data-wallet-available-value"]).to eq("2000")
    expect(root["data-wallet-minimum-value"]).to eq(WalletDepositService::MINIMUM_DEPOSIT_CENTS.to_s)
    expect(page.at_css(".wl-title").text).to eq("Adicionar saldo")
    expect(page.at_css(".wl-subtitle").text).to eq("Coloque saldo na sua carteira e use quando quiser.")
    expect(page.at_css("a.wl-back")["href"]).to eq("/carteira")
    expect(page.at_css(".wl-amount-card-label").text).to eq("Valor a adicionar")
    expect(page.at_css("#wl-amount")["value"]).to eq("50,00")
    expect(page.at_css(".wl-after").text.squish).to eq("Saldo depois: R$ 70,00")
    expect(page.css(".wl-preset").map { |b| b.text.squish }).to eq([ "R$ 20", "R$ 50", "R$ 100", "Outro" ])
    expect(page.at_css(".wl-preset.is-active").text).to eq("R$ 50")
    expect(page.at_css(".wl-note").text.squish).to eq("O saldo fica guardado na sua carteira, e você pode sacar via Pix quando quiser.")
    expect(page.at_css(".wl-submit").text.squish).to eq("Adicionar R$ 50,00")
    expect(page.at_css(".wl-footer-note").text.squish).to eq("Você conclui o pagamento no Mercado Pago")
  end
end

RSpec.describe "Sacar via Pix (/carteira/sacar)", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let(:user) { create(:user, onboarding_completed: true, plan: free_plan) }

  before { sign_in user, scope: :user }

  it "começa no disponível, com a chave Pix salva e o mínimo do serviço" do
    user.create_wallet!(balance_cents: 30_000, pending_withdrawal_cents: 5_000,
                        pix_key: "samuel@example.com", pix_key_type: "email")
    get "/carteira/sacar"
    page = Nokogiri::HTML(response.body)
    root = page.at_css('[data-controller="wallet"]')

    expect(root["data-wallet-mode-value"]).to eq("withdraw")
    expect(root["data-wallet-available-value"]).to eq("25000")
    expect(root["data-wallet-key-type-value"]).to eq("email")
    expect(page.at_css(".wl-title").text).to eq("Sacar via Pix")
    expect(page.at_css(".wl-subtitle").text).to eq("O dinheiro vai direto para a sua conta.")
    expect(page.at_css(".wl-amount-card-label").text).to eq("Quanto você quer sacar?")
    expect(page.at_css("#wl-amount")["value"]).to eq("250,00")
    expect(page.at_css(".wl-available").text.squish).to eq("Disponível: R$ 250,00 Sacar tudo")
    expect(page.at_css(".wl-section-title").text).to eq("Para onde vai o dinheiro?")
    expect(page.css(".wl-key").map { |b| [ b.text, b["data-key-type"] ] })
      .to eq([ %w[CPF cpf], %w[E-mail email], %w[Telefone phone], %w[Aleatória random] ])
    expect(page.at_css(".wl-key.is-active").text).to eq("E-mail")
    expect(page.at_css(".wl-key-input")["value"]).to eq("samuel@example.com")
    expect(page.at_css(".wl-key-input")["placeholder"]).to eq("seunome@email.com")
    minimum = ActionController::Base.helpers.number_to_currency(WithdrawalService::MINIMUM_AMOUNT_CENTS / 100.0, unit: "R$ ", separator: ",", delimiter: ".")
    expect(page.at_css(".wl-note").text.squish).to eq("Saque mínimo de #{minimum}. O valor cai na sua conta em até 1 dia útil.".squish)
    expect(page.at_css(".wl-submit").text.squish).to eq("Sacar R$ 250,00")
    expect(page.at_css(".wl-footer-note").text).to eq("Confira sua chave Pix antes de confirmar.")
  end

  it "sem chave salva: CPF escolhido e campo vazio" do
    get "/carteira/sacar"
    page = Nokogiri::HTML(response.body)

    expect(page.at_css(".wl-key.is-active").text).to eq("CPF")
    expect(page.at_css(".wl-key-input")["value"]).to be_blank
    expect(page.at_css(".wl-key-input")["placeholder"]).to eq("000.000.000-00")
    expect(page.at_css(".wl-submit").text.squish).to eq("Sacar")
  end
end
