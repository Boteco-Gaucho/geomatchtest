require "rails_helper"

# Entrar (/users/sign_in) — devise/sessions/new no visual do mockup
RSpec.describe "Entrar", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let(:user) { create(:user, onboarding_completed: true, plan: free_plan) }

  it "mostra a tela do mockup, com Criar conta no cabeçalho" do
    get "/users/sign_in"
    page = Nokogiri::HTML(response.body)

    expect(page.at_css(".au-header a.au-login").text).to eq("Criar conta")
    expect(page.at_css(".au-header a.au-login")["href"]).to eq("/users/sign_up")
    expect(page.at_css(".site-header")).to be_nil
    expect(page.at_css(".li-live").text.squish).to eq("Ao vivo agora · gente perto de você")
    expect(page.at_css(".li-title").text).to eq("Bem-vindo ao GeoMatch")
    expect(page.at_css(".li-subtitle").text).to eq("Entre e veja quem está por perto agora.")
    expect(page.css(".su-label").map(&:text)).to eq([ "E-mail", "Senha" ])
    expect(page.at_css(".su-eye")).to be_present
    expect(page.at_css(".li-remember").text.squish).to eq("Lembrar de mim")
    expect(page.at_css("a.li-forgot")["href"]).to eq("/users/password/new")
    expect(page.at_css("input.su-submit")["value"]).to eq("Entrar")
    expect(page.at_css(".su-login").text.squish).to eq("Novo por aqui? Criar conta")
    expect(page.at_css(".au-footer")).to be_present
  end

  it "entra com e-mail e senha, e Lembrar de mim guarda o cookie" do
    get "/users/sign_in"
    post "/users/sign_in", params: { user: { email: user.email, password: "password123", remember_me: "1" } }

    expect(response).to have_http_status(:redirect)
    expect(response.cookies["remember_user_token"]).to be_present
  end

  it "senha errada: volta para a tela com o aviso" do
    get "/users/sign_in"
    post "/users/sign_in", params: { user: { email: user.email, password: "errada" } }

    expect(response).to have_http_status(:unprocessable_entity)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("#toast-container .toast--alert").text).to include("E-mail ou senha inválidos.")
    expect(page.at_css(".li-card")).to be_present
  end
end
