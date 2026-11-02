require "rails_helper"

RSpec.describe "Central de Segurança (/safety_center)", type: :request do
  let(:me) { create(:user, username: "Samuel", onboarding_completed: true) }

  def open_safety_center
    sign_in me, scope: :user
    get "/safety_center"
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  it "monta o layout do mockup com cada ação levando ao lugar certo" do
    page = open_safety_center

    expect(page.at_css(".sc-title").text).to eq("Central de Segurança")
    expect(page.at_css(".sc-subtitle").text).to eq("Segurança a um toque de distância.")
    expect(page.at_css(".sc-back")["href"]).to eq("/meu-perfil")

    call = page.at_css("a.sc-call")
    expect(call["href"]).to eq("tel:190")
    expect(call.text.squish).to eq("Ligar 190 Polícia")

    expect(page.at_css(".sc-section-title").text).to eq("Outras ações")
    share, report = page.css(".sc-card")
    expect(share.name).to eq("button")
    expect(share["data-action"]).to eq("safety-center#shareLocation")
    expect(share.text.squish).to eq("Compartilhar local Enviar localização atual")
    expect(report["href"]).to eq("/report_incident")
    expect(report.text.squish).to eq("Denunciar Reportar um incidente")

    panic, history = page.css(".sc-row")
    expect(panic.name).to eq("button")
    expect(panic["data-action"]).to eq("safety-center#panic")
    expect(panic.text.squish).to eq("Modo Pânico Enviar alerta de emergência")
    expect(history["href"]).to eq("/safety_center/history")
    expect(history.text.squish).to eq("Bloqueados e denúncias Perfis bloqueados e status das denúncias")

    expect(page.at_css(".sc-tips-title").text).to eq("Dicas para se sentir à vontade")
    expect(page.css(".sc-tip-number").map(&:text)).to eq(%w[01 02 03 04])
    expect(page.css(".sc-tip-title").map(&:text))
      .to eq([ "Confie no seu instinto", "Prefira lugares movimentados", "Conte com a gente", "Nos conte o que aconteceu" ])
  end

  it "liga o controller com o nome usado no alerta do Modo Pânico e começa com o painel de reserva fechado" do
    page = open_safety_center

    expect(page.at_css("[data-controller='safety-center']")["data-safety-center-name-value"]).to eq(me.display_name)
    expect(page.at_css("[data-safety-center-target='sheet']")["hidden"]).not_to be_nil
    expect(response.body).not_to include("navigator.geolocation") # o JS saiu da view para o controller
  end

  it "exige login" do
    get "/safety_center"

    expect(response).to redirect_to(new_user_session_path)
  end
end
