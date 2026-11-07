require "rails_helper"

# Esqueceu a senha? (/users/password/new) — devise/passwords/new no visual do mockup
RSpec.describe "Esqueceu a senha", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:free_plan) { create(:plan, :free) }
  let(:user) { create(:user, onboarding_completed: true, plan: free_plan) }

  it "mostra a tela do mockup" do
    get "/users/password/new"
    page = Nokogiri::HTML(response.body)

    expect(page.at_css(".au-header a.au-login").text).to eq("Entrar")
    expect(page.at_css("a.fp-back")["href"]).to eq("/users/sign_in")
    expect(page.at_css(".fp-icon svg")).to be_present
    expect(page.at_css(".fp-title").text).to eq("Esqueceu a senha?")
    expect(page.at_css(".fp-subtitle").text)
      .to eq("Acontece. Digite o e-mail da sua conta e enviamos um link para você criar uma nova senha.")
    expect(page.at_css(".su-label").text).to eq("E-mail")
    expect(page.at_css("#user_email")["placeholder"]).to eq("seu@email.com")
    expect(page.at_css("input.su-submit")["value"]).to eq("Enviar link")
    expect(page.at_css(".fp-note").text).to eq("Não chegou em alguns minutos? Confira a caixa de spam.")
    expect(page.at_css(".su-login").text.squish).to eq("Lembrou a senha? Entrar")
    expect(page.at_css(".au-footer")).to be_present
  end

  it "Enviar link manda o e-mail de redefinição e mostra \"Link enviado!\"" do
    expect {
      post "/users/password", params: { user: { email: user.email } }
    }.to change { ActionMailer::Base.deliveries.size }.by(1)

    expect(response).to redirect_to(password_reset_sent_path)
    expect(ActionMailer::Base.deliveries.last.to).to eq([ user.email ])

    follow_redirect!
    page = Nokogiri::HTML(response.body)
    expect(page.at_css(".fp-title").text).to eq("Link enviado!")
    expect(page.at_css(".rs-subtitle").text.squish)
      .to eq("Enviamos um link para #{user.email}. Abra o e-mail e toque nele para criar uma nova senha.")
    expect(page.css(".rs-tips li").map { |li| li.text.squish }).to eq([
      "O link vale por tempo limitado, então use logo.",
      "Não achou? Olhe a caixa de spam ou promoções."
    ])
    expect(page.at_css("a.rs-primary")["href"]).to eq("/users/sign_in")
    expect(page.at_css("a.rs-primary").text).to eq("Voltar para entrar")
    resend = page.at_css("form.rs-resend-form")
    expect(resend["action"]).to eq("/users/password")
    expect(resend.at_css("input[name='user[email]']")["value"]).to eq(user.email)
    expect(resend.at_css("button.rs-resend").key?("disabled")).to be(true)
    expect(resend.at_css("button.rs-resend").text.squish).to eq("Reenviar link em 1:00")
    expect(resend["data-resend-timer-seconds-value"]).to eq("60")
    expect(page.at_css(".su-login").text.squish).to eq("E-mail errado? Usar outro e-mail")
    expect(page.at_css("#toast-container .toast")).to be_nil # sem o aviso "Você receberá um e-mail…"
  end

  it "depois de 1 minuto o Reenviar já vem liberado e manda outro e-mail" do
    post "/users/password", params: { user: { email: user.email } }

    travel 61.seconds do
      get "/users/password/enviado"
      button = Nokogiri::HTML(response.body).at_css("button.rs-resend")
      expect(button.key?("disabled")).to be(false)
      expect(button.text.squish).to eq("Reenviar link")

      expect {
        post "/users/password", params: { user: { email: user.email } }
      }.to change { ActionMailer::Base.deliveries.size }.by(1)
      expect(response).to redirect_to(password_reset_sent_path)
    end
  end

  it "sem ter pedido o link, /users/password/enviado volta para o Esqueceu a senha?" do
    get "/users/password/enviado"

    expect(response).to redirect_to(new_user_password_path)
  end

  it "e-mail sem conta: o erro aparece no cartão" do
    post "/users/password", params: { user: { email: "ninguem@example.com" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(Nokogiri::HTML(response.body).at_css(".fp-card .su-errors").text.squish).to eq("E-mail não foi encontrado")
  end
end
