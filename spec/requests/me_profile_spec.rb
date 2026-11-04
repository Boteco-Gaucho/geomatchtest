require "rails_helper"

RSpec.describe "Meu Perfil (/meu-perfil)", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let!(:plus) do
    create(:plan, code: "plus", name: "Plus", price_cents: 2990,
                  features: { "see_who_liked_me" => true, "see_who_i_liked" => true,
                              "unlimited_messages" => true, "likes_right_unlimited" => true })
  end
  let!(:gold) do
    create(:plan, code: "gold", name: "Gold", price_cents: 4990,
                  features: { "see_who_liked_me" => true, "see_who_i_liked" => true, "unlimited_messages" => true,
                              "likes_right_unlimited" => true, "allow_invisible" => true })
  end

  def open_profile(user)
    sign_in user, scope: :user
    get "/meu-perfil"
    expect(response).to have_http_status(:ok)
    response.body
  end

  def offer_card(body, code)
    body[/<article class="me-offer me-offer--#{code}">.*?<\/article>/m].to_s
  end

  it "assinante Gold verificado: selos, plano ativo e carrossel sem oferecer o que já tem" do
    user = create(:user, onboarding_completed: true, plan: gold, verified: true, premium_until: Date.new(2126, 6, 2))

    body = open_profile(user)

    expect(body).to include("texto-perfil") # título "Perfil" continua o PNG dourado
    expect(body).to include('href="/safety_center"')
    expect(body).to include("Identidade verificada")
    expect(body).to include('me-badge--plan me-badge--gold">Gold</span>')
    expect(body).to include("GeoMatch Gold")
    expect(body).to include("Ativo até 02/06/2126")
    expect(offer_card(body, "free")).to include("Plano básico")
    expect(offer_card(body, "plus")).to include("Incluído no seu plano")
    expect(offer_card(body, "gold")).to include("Seu plano atual")
    expect(body).not_to include('action="/checkout')
  end

  it "plano grátis sem verificação: convite para verificar e os cards de plano abrindo /plans" do
    user = create(:user, onboarding_completed: true, plan: free_plan)

    body = open_profile(user)

    expect(body).to include('<a class="me-badge me-badge--verify" href="/verificacao">Verificar identidade</a>')
    expect(body).to include("Plano gratuito")
    expect(offer_card(body, "free")).to include("Seu plano atual")
    expect(offer_card(body, "plus")).to include('class="me-offer-link"', 'href="/plans#plano-plus"', "Assinar Plus")
    expect(offer_card(body, "gold")).to include('href="/plans#plano-gold"', "Assinar Gold")
    expect(offer_card(body, "free")).to include('href="/plans#plano-free"')
    expect(body).not_to include('action="/checkout') # o checkout fica em /plans
  end

  it "mantém carteira, cupom, tema, sair e encerrar conta" do
    body = open_profile(create(:user, onboarding_completed: true, plan: free_plan))

    expect(body).to include('data-controller="balance-visibility"')
    expect(body).to include('action="/apply_coupon"')
    expect(body).to include('data-controller="theme"')
    expect(body).to include("document.getElementById('logout-modal').classList.add('show')")
    expect(body).to include("Encerrar minha conta")
    expect(body).to include('id="upgrade-modal-container"')
  end

  describe "card de completude" do
    let(:user) { create(:user, onboarding_completed: true, plan: free_plan) }
    let(:all_done) do
      { avatar: true, username: true, bio: true, birthdate: true, gender: true, interested_in: true,
        city: true, hobbies: true, album_photos: true, verified: true }
    end

    it "sugere o próximo item que falta e leva à edição" do
      allow_any_instance_of(User).to receive(:profile_completion_checks).and_return(all_done.merge(bio: false))

      body = open_profile(user)

      expect(body).to include("Perfil 90% completo")
      expect(body).to include("Falta 1 item")
      expect(body).to include("Adicione uma bio curta para quem está por perto saber puxar assunto.")
      expect(body).to include('<a class="me-btn-gold" href="/profile/edit">Completar perfil</a>')
    end

    it "quando só falta a verificação, \"Completar perfil\" vai direto para ela" do
      allow_any_instance_of(User).to receive(:profile_completion_checks).and_return(all_done.merge(verified: false))

      expect(open_profile(user)).to include('<a class="me-btn-gold" href="/verificacao">Completar perfil</a>')
    end

    it "perfil completo: sem botão de completar" do
      allow_any_instance_of(User).to receive(:profile_completion_checks).and_return(all_done)

      body = open_profile(user)

      expect(body).to include("Perfil completo")
      expect(body).not_to include("Completar perfil")
    end
  end

  it "documentos recusados: mostra o motivo e o reenvio" do
    user = create(:user, onboarding_completed: true, plan: free_plan,
                         ai_moderation_status: "rejected", ai_moderation_details: { "reason" => "face_mismatch" })

    body = open_profile(user)

    expect(body).to include("Documentos não aprovados")
    expect(body).to include("O rosto da selfie não corresponde ao documento.")
    expect(body).to include("Enviar novos documentos")
  end
end
