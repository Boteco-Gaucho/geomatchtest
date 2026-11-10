require "rails_helper"

# Editar perfil: trocar a foto principal mostra "Foto atualizada" com Desfazer
RSpec.describe "Troca da foto principal", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let!(:free_plan) { create(:plan, :free) }
  let(:me) { create(:user, onboarding_completed: true, plan: free_plan) }
  let(:img) { Rails.root.join("app/assets/images") }

  before do
    me.avatar.detach if me.avatar.attached?
    sign_in me, scope: :user
  end

  def upload(name)
    post "/profile/apply_crop", params: { avatar: Rack::Test::UploadedFile.new(img.join(name), "image/png") },
                                headers: { "Accept" => "application/json" }
    expect(response).to have_http_status(:ok)
  end

  def toast
    get "/profile/edit"
    Nokogiri::HTML(response.body).at_css(".tt-toast--photo")
  end

  it "primeira foto: \"Foto adicionada\", sem Desfazer" do
    upload("clara.png")

    t = toast
    expect(t.at_css(".tt-title").text).to eq("Foto adicionada")
    expect(t.at_css(".tt-action")).to be_nil
  end

  it "trocar: \"Foto atualizada\" com Desfazer; desfazer volta a anterior e apaga a nova" do
    upload("clara.png")
    first_blob = me.reload.avatar.blob
    get "/profile/edit" # consome o aviso da primeira

    expect { upload("bloco-upgrade-gold.png") }.to have_enqueued_job(AvatarUndoCleanupJob).with(first_blob.id)
    second_blob = me.reload.avatar.blob
    expect(second_blob.id).not_to eq(first_blob.id)
    expect(ActiveStorage::Blob.exists?(first_blob.id)).to be(true) # guardada para o Desfazer

    t = toast
    expect(t.at_css(".tt-title").text).to eq("Foto atualizada")
    expect(t.at_css(".tt-text").text).to eq("Sua nova foto principal já aparece no perfil.")
    expect(t.at_css("form.tt-action-form")["action"]).to eq("/profile/undo_avatar")
    expect(t.at_css(".tt-action").text).to eq("Desfazer")

    post "/profile/undo_avatar"
    expect(response).to redirect_to("/profile/edit")
    expect(me.reload.avatar.blob.id).to eq(first_blob.id)
    follow_redirect!
    expect(Nokogiri::HTML(response.body).at_css(".tt-toast--photo .tt-title").text).to eq("Foto anterior de volta")

    post "/profile/undo_avatar" # de novo: nada para desfazer
    expect(flash[:alert]).to eq("Não dá mais para desfazer a troca da foto.")
    expect(me.reload.avatar.blob.id).to eq(first_blob.id)
  end

  it "depois do prazo não desfaz, e a limpeza apaga a foto anterior que ninguém usa" do
    upload("clara.png")
    first_blob = me.reload.avatar.blob
    upload("bloco-upgrade-gold.png")

    travel(UsersController::AVATAR_UNDO_WINDOW + 1.minute) do
      post "/profile/undo_avatar"
      expect(flash[:alert]).to be_present
      AvatarUndoCleanupJob.perform_now(first_blob.id)
    end
    expect(ActiveStorage::Blob.exists?(first_blob.id)).to be(false)
    expect(me.reload.avatar.attached?).to be(true)
  end
end
