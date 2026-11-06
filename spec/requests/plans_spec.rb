require "rails_helper"

RSpec.describe "Planos (/plans)", type: :request do
  let(:plus_features) do
    { "likes_right_unlimited" => true, "see_who_liked_me" => true, "see_who_i_liked" => true,
      "unlimited_messages" => true, "allow_invisible" => false, "search_by_distance" => false,
      "rewind_profile" => false }
  end
  let(:gold_features) { plus_features.merge("allow_invisible" => true, "search_by_distance" => true, "rewind_profile" => true) }

  let!(:free) { create(:plan, :free, description: "Plano gratuito") }
  let!(:plus) { create(:plan, code: "plus", name: "Plus", price_cents: 1999, features: plus_features) }
  let!(:gold) { create(:plan, code: "gold", name: "Gold", price_cents: 4799, features: gold_features) }

  def card(page, code)
    page.at_css("#plano-#{code}")
  end

  context "sem login" do
    # PlansController libera o index (vitrine); o /checkout é que pede login
    it "abre a vitrine sem 'Seu plano' e com Assinar nos planos pagos" do
      get "/plans"
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)

      expect(page.css(".pl-tag--current")).to be_empty
      expect(page.css("button.pl-cta--buy").map(&:text)).to eq([ "Assinar Gold", "Assinar Plus" ])
    end
  end

  context "com login" do
    let(:user) { create(:user, onboarding_completed: true, plan: free) }

    before { sign_in user, scope: :user }

    it "monta a tela do mockup: título, do mais caro ao mais barato, preço e aviso do checkout" do
      get "/plans"
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)

      expect(page.at_css(".pl-title").text.squish).to eq("Desbloqueie o melhor do GeoMatch")
      expect(page.css(".pl-trust li").map { |li| li.text.squish }).to eq([ "Pagamento seguro via Mercado Pago", "Cancele quando quiser" ])
      expect(page.css(".pl-card").map { |c| c["id"] }).to eq(%w[plano-gold plano-plus plano-free])
      expect(card(page, "gold")["class"]).to include("pl-card--gold")
      expect(card(page, "gold").at_css(".pl-price").text.squish).to eq("R$ 47,99 /mês")
      expect(card(page, "free").at_css(".pl-price").text.squish).to eq("R$ 0 para sempre")
      expect(card(page, "plus").at_css(".pl-tagline").text).to eq("Descubra quem curtiu você e aproveite o mapa sem limites.")
      expect(card(page, "free").css(".pl-perks")).to be_empty
      expect(page.at_css(".pl-footnote").text).to include("checkout seguro do Mercado Pago")
    end

    it "marca os recursos pelo que o plano tem de fato (o que não existe ainda aparece como Em breve)" do
      get "/plans"
      page = Nokogiri::HTML(response.body)

      plus_perks = card(page, "plus").css(".pl-perks li")
      expect(plus_perks.size).to eq(8)
      expect(plus_perks.select { |li| li["class"] == "is-yes" }.map { |li| li.text.squish })
        .to eq([ "Interação ilimitada no mapa", "Ver quem curtiu você", "Ver quem você curtiu", "Mensagens ilimitadas" ])
      expect(card(page, "gold").css(".pl-perks li.is-no")).to be_empty
      expect(card(page, "gold").at_css(".pl-soon").parent.text.squish).to eq("Esconder minha idade Em breve")
    end

    it "no Free: 'Seu plano' no Free e Assinar indo ao checkout nos pagos; Recomendado no Plus" do
      get "/plans"
      page = Nokogiri::HTML(response.body)

      expect(card(page, "free").at_css(".pl-tag--current")).to be_present
      expect(card(page, "free").at_css(".pl-cta").text).to eq("Seu plano atual")
      expect(card(page, "plus").at_css(".pl-tag--recommended").text).to eq("Recomendado")
      expect(card(page, "plus").at_css("form")["action"]).to eq("/checkout?plan_id=#{plus.id}")
      expect(card(page, "plus").at_css("form")["data-turbo"]).to eq("false")
      expect(card(page, "gold").at_css("button.pl-cta--buy").text).to eq("Assinar Gold")
    end

    it "o plano marcado como recomendado no banco ganha a etiqueta no lugar do Plus" do
      gold.update!(is_recommended: true)

      get "/plans"
      page = Nokogiri::HTML(response.body)

      expect(card(page, "gold").at_css(".pl-tag--recommended")).to be_present
      expect(card(page, "plus").at_css(".pl-tag--recommended")).to be_nil
    end

    describe "GET /plans/modal (upgrade para o Gold)" do
      it "modo oculto: layout do mockup, Assinar Gold indo ao checkout e Agora não fechando" do
        get "/plans/modal", params: { type: "invisible" }
        expect(response).to have_http_status(:ok)
        page = Nokogiri::HTML(response.body)

        expect(response.body).not_to include("<html") # sem layout: o JS injeta no container
        expect(page.at_css(".um-title").text.squish).to eq("Fique invisível com o Gold")
        expect(page.at_css(".um-text").text.squish).to eq("Veja quem está por perto sem aparecer no mapa. Você decide quando ser visto.")
        expect(page.css(".um-perks li").map { |li| li.text.squish })
          .to eq([ "Modo oculto no mapa", "Ver quem curtiu você", "Mensagens ilimitadas", "Explorar outras cidades" ])
        form = page.at_css("form.um-cta-form")
        expect(form["action"]).to eq("/checkout?plan_id=#{gold.id}")
        expect(form["data-turbo"]).to eq("false")
        expect(page.at_css(".um-price").text).to eq("R$ 47,99/mês · cancele quando quiser")
        expect(page.css(".close-modal-btn").map { |b| b["class"] }).to eq([ "close-modal-btn um-close", "close-modal-btn um-later" ])
      end

      it "sem plano Gold ativo, o botão leva a /plans" do
        gold.update!(active: false)

        get "/plans/modal", params: { type: "invisible" }
        page = Nokogiri::HTML(response.body)

        expect(page.at_css("a.um-cta")["href"]).to eq("/plans#plano-gold")
        expect(page.css("form.um-cta-form")).to be_empty
      end
    end

    it "no Gold: 'Ativo até' no Gold, nada para assinar abaixo dele" do
      user.update!(plan: gold, premium_until: Time.zone.local(2126, 6, 2, 12))

      get "/plans"
      page = Nokogiri::HTML(response.body)

      expect(card(page, "gold").at_css(".pl-tag--current").text.squish).to eq("Seu plano")
      expect(card(page, "gold").at_css(".pl-cta").text).to eq("Ativo até 02/06/2126")
      expect(card(page, "plus").at_css(".pl-cta").text).to eq("Incluído no seu plano")
      expect(card(page, "free").at_css(".pl-cta").text).to eq("Plano gratuito")
      expect(response.body).not_to include('action="/checkout')
    end
  end
end
