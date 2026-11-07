require "rails_helper"

# Avisos do topo (shared/_flash): cor de cada tipo
RSpec.describe "Avisos (flash)", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let(:user) { create(:user, onboarding_completed: true, plan: free_plan) }

  it "\"Você já está autenticado.\" (reabrir o app já logado) aparece em verde, não como erro" do
    # Login de verdade, como no navegador: abre a tela e envia (o sign_in de teste do
    # Warden se embaralha com a tela de login do Devise)
    get "/users/sign_in"
    post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }
    get "/users/sign_in"
    expect(response).to have_http_status(:redirect)
    follow_redirect!

    toast = Nokogiri::HTML(response.body).at_css("#toast-container .toast")
    expect(toast.at_css(".toast__message").text).to eq("Você já está autenticado.")
    expect(toast["class"].split).to include("toast--success")
    expect(toast["class"]).not_to include("toast--alert")
  end

  it "os outros alertas continuam vermelhos" do
    get "/meu-perfil" # sem login: volta para a tela de login com um alerta
    follow_redirect!

    toast = Nokogiri::HTML(response.body).at_css("#toast-container .toast")
    expect(toast.at_css(".toast__message").text).to eq(I18n.t("devise.failure.unauthenticated"))
    expect(toast["class"].split).to include("toast--alert")
  end
end
