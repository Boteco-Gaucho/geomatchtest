require "rails_helper"

RSpec.describe "Bloqueados e denúncias (/safety_center/history)", type: :request do
  let(:me)   { create(:user, username: "Samuel", onboarding_completed: true) }
  let(:gabi) { create(:user, username: "Gabi Test") }
  let(:fany) { create(:user, username: "Fany") }

  def open_history
    sign_in me, scope: :user
    get "/safety_center/history"
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  it "monta o topo do mockup e, sem nada registrado, os dois estados vazios" do
    page = open_history

    expect(page.at_css(".sc-title").text).to eq("Bloqueados e denúncias")
    expect(page.at_css(".sc-subtitle").text).to eq("Quem você bloqueou e o que você relatou.")
    expect(page.at_css(".sc-back")["href"]).to eq("/safety_center")

    expect(page.css(".sh-title").map(&:text)).to eq([ "Bloqueados", "Minhas denúncias" ])
    expect(page.css(".sh-count").map(&:text)).to eq(%w[Nenhum Nenhuma])
    expect(page.css(".sh-empty-title").map(&:text)).to eq([ "Ninguém bloqueado", "Tudo tranquilo por aqui" ])

    link = page.at_css(".sh-empty-link")
    expect(link.text).to eq("Fazer uma denúncia")
    expect(link["href"]).to eq("/report_incident")
    expect(page.at_css(".sh-note").text)
      .to eq("As denúncias ficam registradas e não podem ser editadas nem apagadas depois do envio.")
  end

  it "lista os perfis bloqueados, cada um com o seu Desbloquear" do
    me.blocks_sent.create!(blocked: gabi)
    me.blocks_sent.create!(blocked: fany)

    page = open_history

    expect(page.css(".sh-count").first.text).to eq("2 perfis")
    expect(page.css(".sh-blocked strong").map(&:text)).to contain_exactly("Gabi Test", "Fany")
    expect(page.css(".sh-blocked-text span").map(&:text).uniq).to eq([ "Não vê seu perfil nem fala com você" ])

    form = page.css("form.sh-unblock-form").find { |f| f["action"] == "/users/#{gabi.id}/unblock" }
    expect(form.at_css("input[name='_method']")["value"]).to eq("delete")
    expect(form.at_css("button.sh-unblock").text).to eq("Desbloquear")
    expect(form["data-turbo-confirm"]).to include("Desbloquear Gabi Test?")
  end

  it "conta um único bloqueado no singular" do
    me.blocks_sent.create!(blocked: gabi)

    expect(open_history.css(".sh-count").first.text).to eq("1 perfil")
  end

  it "mostra as denúncias enviadas com tipo, pessoa e andamento, da mais nova para a mais antiga" do
    create(:report, reporter: me, category: "fake_profile", reported_user: fany,
                    description: "Perfil com fotos de outra pessoa.", created_at: Time.zone.local(2026, 3, 12, 10),
                    resolved_at: Time.zone.local(2026, 3, 13, 10))
    create(:report, reporter: me, category: "spam", description: "Mandou propaganda.",
                    created_at: Time.zone.local(2026, 4, 2, 10))
    create(:report, reporter: gabi, description: "Denúncia de outra pessoa.")

    page = open_history

    expect(page.css(".sh-count").last.text).to eq("2 enviadas")
    expect(page.css(".sh-report-kind").map(&:text)).to eq([ "Outro", "Perfil falso" ]) # "spam" não tem chip na tela
    expect(page.css(".sh-status").map(&:text)).to eq([ "Em análise", "Analisada" ])
    expect(page.css(".sh-report-meta").map { |meta| meta.text.squish }).to eq([ "02/04/2026", "12/03/2026 · sobre Fany" ])
    expect(page.css(".sh-report-text").map(&:text)).to eq([ "Mandou propaganda.", "Perfil com fotos de outra pessoa." ])
    expect(page.at_css(".sh-empty-link")).to be_nil
    expect(page.at_css(".sh-note")).to be_present
  end

  it "sem a coluna nova em produção, lista as denúncias sem a pessoa" do
    create(:report, reporter: me, reported_user: fany, description: "Relato.", created_at: Time.zone.local(2026, 3, 12, 10))
    allow(Report).to receive(:reported_user_column?).and_return(false)

    expect(open_history.at_css(".sh-report-meta").text.squish).to eq("12/03/2026")
  end

  it "desbloquear volta para esta tela" do
    me.blocks_sent.create!(blocked: gabi)
    sign_in me, scope: :user

    delete "/users/#{gabi.id}/unblock"

    expect(response).to redirect_to("/safety_center/history")
    expect(me.blocked_users.reload).to be_empty
  end

  it "exige login" do
    get "/safety_center/history"

    expect(response).to redirect_to(new_user_session_path)
  end
end
