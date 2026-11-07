require "rails_helper"

# Criar conta (/users/sign_up) — devise/registrations/new no visual do mockup
RSpec.describe "Criar conta", type: :request do
  let!(:free_plan) { create(:plan, :free) }

  def sign_up(overrides = {})
    post "/users", params: { user: {
      username: "João Silva", email: "joao@example.com", phone: "(71) 99999-9999",
      password: "segredo1", password_confirmation: "segredo1", terms_of_use: "1", data_policy: "1"
    }.merge(overrides) }
  end

  it "mostra a tela do mockup, com cabeçalho e rodapé próprios" do
    get "/users/sign_up"
    page = Nokogiri::HTML(response.body)

    expect(page.at_css(".au-header a.au-login").text).to eq("Entrar")
    expect(page.at_css(".site-header")).to be_nil # sem o "Cadastrar" do cabeçalho comum
    expect(page.at_css(".su-title").text).to eq("Crie sua conta")
    expect(page.at_css(".su-subtitle").text).to eq("Descubra quem está a até 300 m de você.")
    expect(page.css(".su-label").map(&:text)).to eq([ "Nome completo", "E-mail", "Celular", "Senha", "Confirmar senha" ])
    expect(page.at_css("#user_phone")["placeholder"]).to eq("(71) 99999-9999")
    expect(page.at_css(".su-ddi").text).to eq("+55")
    expect(page.at_css("#su-password-hint").text.squish).to eq("Mínimo de 6 caracteres")
    expect(page.css(".su-eye").size).to eq(2)
    expect(page.css(".su-check").map { |c| c.text.squish })
      .to eq([ "Li e aceito os Termos de Uso", "Aceito a Política de Uso de Dados" ])
    expect(page.at_css("input.su-submit")["value"]).to eq("Criar conta")
    expect(page.at_css(".su-privacy").text.squish).to eq("Sua localização exata nunca é mostrada")
    expect(page.at_css(".su-login").text.squish).to eq("Já tem conta? Entrar")
    expect(page.at_css(".au-footer h2").text).to eq("Sobre")
    expect(page.at_css(".site-footer")).to be_nil
  end

  it "cria a conta com o celular +55 e segue para o onboarding" do
    expect { sign_up }.to change(User, :count).by(1)

    expect(response).to redirect_to(onboarding_path)
    user = User.find_by(email: "joao@example.com")
    expect(user.username).to eq("João Silva")
    expect(user.phone).to eq("+5571999999999")
  end

  it "erros aparecem no cartão e os termos são obrigatórios" do
    expect { sign_up(terms_of_use: "0") }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css(".su-card .su-errors").text).to include("Os Termos de Uso devem ser aceitos")
    expect(page.at_css("#user_phone")["value"]).to eq("(71) 99999-9999") # sem o +55, que fica fixo ao lado
  end

  it "as outras páginas sem login continuam com o cabeçalho e o rodapé de sempre" do
    get "/termos-de-uso"
    page = Nokogiri::HTML(response.body)

    expect(page.at_css(".site-header")).to be_present
    expect(page.at_css(".au-header")).to be_nil
  end
end
