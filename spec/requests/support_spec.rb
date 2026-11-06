require "rails_helper"

RSpec.describe "Ajuda e suporte (/suporte)", type: :request do
  let!(:free) { create(:plan, :free) }

  def page_html
    Nokogiri::HTML(response.body)
  end

  context "com login (aberta por 'Ajuda e suporte' em Meu Perfil)" do
    let(:user) { create(:user, onboarding_completed: true, plan: free) }

    before { sign_in user, scope: :user }

    it "monta a tela do mockup: topo, Fale com a gente, Central de Segurança, FAQ e dica" do
      get "/suporte"
      expect(response).to have_http_status(:ok)
      page = page_html

      expect(page.at_css(".hs-back")["href"]).to eq("/meu-perfil")
      expect(page.at_css(".hs-title").text.squish).to eq("Ajuda e suporte")
      expect(page.at_css(".hs-subtitle").text).to eq("Precisa de ajuda? Estamos aqui para você.")

      expect(page.at_css(".hs-contact-title").text).to eq("Fale com a gente")
      expect(page.at_css(".hs-contact-text").text).to eq("Respondemos em até 48 horas úteis")
      button = page.at_css("a.hs-contact-btn")
      expect(button.text).to eq("Enviar e-mail")
      expect(button["href"]).to start_with("mailto:suporte@geomatchbr.com")
      expect(page.at_css(".hs-contact-email").text).to eq("suporte@geomatchbr.com")

      safety = page.at_css("a.hs-safety")
      expect(safety["href"]).to eq("/safety_center")
      expect(safety.text.squish).to eq("Central de Segurança Se for urgente, comece por aqui")

      expect(page.at_css(".hs-section-title").text).to eq("Perguntas frequentes")
      items = page.css(".hs-faq details")
      expect(items.map { |d| d.at_css("summary").text.squish })
        .to eq([ "Como excluir minha conta?", "Como cancelar minha assinatura?", "Como denunciar alguém?", "Não recebo notificações" ])
      expect(items.map { |d| d.key?("open") }).to eq([ true, false, false, false ])
      expect(items.first.at_css("strong").text).to eq("Perfil › Configurações › Encerrar conta")

      expect(page.at_css(".hs-note").text.squish)
        .to eq("Para agilizar, conte no e-mail seu nome de usuário e o que aconteceu, com o máximo de detalhes.")
    end

    it "o FAQ do schema.org é JSON válido com as mesmas perguntas, sem HTML" do
      get "/suporte"
      script = page_html.css('script[type="application/ld+json"]').find { |s| s.text.include?("FAQPage") }
      json = JSON.parse(script.text)

      expect(json["@type"]).to eq("FAQPage")
      expect(json["mainEntity"].map { |q| q["name"] }.size).to eq(4)
      expect(json["mainEntity"].first["acceptedAnswer"]["text"]).to start_with("Vá em Perfil › Configurações › Encerrar conta.")
    end
  end

  context "sem login (página pública, link do rodapé)" do
    it "abre sem a Central de Segurança (que pede conta) e com voltar para o início" do
      get "/suporte"
      expect(response).to have_http_status(:ok)
      page = page_html

      expect(page.css(".hs-safety")).to be_empty
      expect(page.at_css(".hs-back")["href"]).to eq("/")
      expect(page.at_css("a.hs-contact-btn")).to be_present
    end
  end
end
