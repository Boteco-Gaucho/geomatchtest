require "rails_helper"

# "Encerrar conta" em Meu Perfil: a folha envia DELETE /users (Devise registrations#destroy).
RSpec.describe "Encerrar conta (DELETE /users)", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let(:user)  { create(:user, onboarding_completed: true, plan: free_plan) }
  let(:other) { create(:user, onboarding_completed: true, plan: free_plan) }

  it "apaga a conta mesmo com curtidas, favoritos, conversas e notificações de outras pessoas apontando para ela" do
    Like.create!(liker: other, liked: user)
    Like.create!(liker: user, liked: other)
    Favorite.create!(user: other, favorited_user: user)
    match = Match.create!(user: other, matched_user: user)
    msg_other = Message.create!(match: match, sender: other, content: "oi")
    msg_user  = Message.create!(match: match, sender: user, content: "olá")
    Reaction.create!(message: msg_user, user: other, emoji: "❤️")
    Reaction.create!(message: msg_other, user: user, emoji: "😂")
    Notification.create!(recipient: other, actor: user, notifiable: match, action: "match")

    sign_in user, scope: :user
    delete "/users"

    expect(response).to have_http_status(:redirect)
    expect(User.exists?(user.id)).to be(false)
    expect(User.exists?(other.id)).to be(true)
    expect(Like.where(liked_id: user.id).or(Like.where(liker_id: user.id))).to be_empty
    expect(Favorite.where(favorited_user_id: user.id)).to be_empty
    expect(Match.exists?(match.id)).to be(false)
    expect(Message.where(id: [ msg_other.id, msg_user.id ])).to be_empty
    expect(Reaction.count).to eq(0)
    expect(Notification.where(actor_id: user.id)).to be_empty
  end

  it "a folha de Meu Perfil leva ao DELETE /users e só libera o botão depois de digitar ENCERRAR" do
    sign_in user, scope: :user
    get "/meu-perfil"
    page = Nokogiri::HTML(response.body)

    row = page.css(".me-settings button.me-row").find { |b| b.text.squish == "Encerrar conta" }
    expect(row["data-action"]).to eq("delete-account-sheet#open")

    wrapper = page.at_css('[data-controller~="delete-account-sheet"]')
    expect(wrapper.at_css(".me-settings")).to be_present # o botão fica dentro do controller

    sheet = wrapper.at_css('[data-delete-account-sheet-target="backdrop"]')
    expect(sheet.key?("hidden")).to be(true)
    expect(sheet.at_css(".ls-title").text).to eq("Encerrar sua conta?")
    expect(sheet.css(".ds-list li").map { |li| li.text.squish })
      .to eq([ "Seu perfil e suas fotos", "Suas curtidas e favoritos", "Todas as suas conversas" ])

    form = sheet.at_css("form.ds-form")
    expect(form["action"]).to eq("/users")
    expect(form.at_css("input[name=_method]")["value"]).to eq("delete")
    expect(form.at_css('input[data-delete-account-sheet-target="input"]')["placeholder"]).to eq("ENCERRAR")
    submit = form.at_css('button[type=submit][data-delete-account-sheet-target="submit"]')
    expect(submit.key?("disabled")).to be(true)
    expect(form.at_css("button.ds-stay")["data-action"]).to eq("delete-account-sheet#close")
  end
end
