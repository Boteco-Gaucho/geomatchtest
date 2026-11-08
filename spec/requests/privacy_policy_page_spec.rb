require "rails_helper"

# Política de privacidade (/politica-de-privacidade) — "Ler a política completa" da tela
# Privacidade e localização (e o link da Criar conta)
RSpec.describe "Política de privacidade", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let(:user) { create(:user, onboarding_completed: true, plan: free_plan) }

  it "a tela Privacidade e localização leva até ela" do
    sign_in user, scope: :user
    get "/privacidade"

    expect(Nokogiri::HTML(response.body).at_css("a.prv-full-policy")["href"]).to eq("/politica-de-privacidade")
  end

  it "logado: visual do mockup, sem navegação, e Entendi volta para Meu Perfil" do
    sign_in user, scope: :user
    get "/politica-de-privacidade"
    page = Nokogiri::HTML(response.body)

    expect(page.at_css(".lg-title").text).to eq("Política de privacidade")
    expect(page.at_css(".lg-updated").text.squish).to eq("Atualizada em 07/11/2026") # data fixa, não a de hoje
    expect(page.at_css("a.lg-back")["href"]).to eq("/privacidade")
    expect(page.at_css(".lg-intro strong").text).to eq("GeoMatch")
    expect(page.css(".lg-toc a").map { |a| a.text.squish }).to eq([
      "1 Controlador", "2 Dados coletados", "3 Finalidades", "4 Compartilhamento", "5 Transferência",
      "6 Retenção", "7 Seus direitos", "8 Segurança", "9 Crianças", "10 Contato"
    ])
    page.css(".lg-toc a").each { |a| expect(page.at_css(a["href"])).to be_present } # âncoras existem
    expect(page.css(".lg-card .lg-h").size).to eq(10)
    expect(page.at_css(".lg-callout").text.squish).to include("dentro do raio de 300 metros")
    expect(page.css(".lg-basis").map(&:text))
      .to eq([ "Execução de Contrato", "Consentimento e Execução de Contrato", "Legítimo Interesse e Obrigação Legal" ])
    expect(page.css(".lg-chips li").size).to eq(5)
    expect(page.at_css("a.lg-contact")["href"]).to eq("mailto:suporte@geomatch.com.br")

    done = page.at_css("a.lg-done")
    expect(done.text).to eq("Entendi")
    expect(done["href"]).to eq("/meu-perfil")
    expect(response.body).not_to include("Voltar para o Cadastro")
    expect(page.at_css(".sidebar")).to be_nil
  end

  it "sem conta (link da Criar conta): Entendi volta para a Criar conta, sem cabeçalho e rodapé" do
    get "/politica-de-privacidade"
    page = Nokogiri::HTML(response.body)

    expect(page.at_css("a.lg-done")["href"]).to eq("/users/sign_up")
    expect(page.at_css(".site-header")).to be_nil
    expect(page.at_css(".site-footer")).to be_nil
  end
end
