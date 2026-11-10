require "rails_helper"

# Editar perfil: X numa foto do álbum → "Foto removida — Você ainda tem N fotos" com Desfazer
RSpec.describe "Remover foto do álbum", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let!(:free_plan) { create(:plan, :free) }
  let(:me) { create(:user, onboarding_completed: true, plan: free_plan) }
  let(:img) { Rails.root.join("app/assets/images") }

  before do
    allow_any_instance_of(User).to receive(:geocode)
    %w[clara.png bloco-upgrade-gold.png bloco-upgrade-plus.png].each do |name|
      me.album_photos.attach(io: File.open(img.join(name)), filename: name, content_type: "image/png")
    end
    sign_in me, scope: :user
  end

  def album_blobs = me.reload.album_photos_attachments.map(&:blob_id)

  it "remove na hora, mostra quantas fotos sobraram e Desfazer devolve na mesma posição" do
    blobs = album_blobs
    middle = me.album_photos_attachments.second
    left = (me.has_real_avatar? ? 1 : 0) + 2

    expect { delete "/album_photos/#{middle.id}", headers: { "HTTP_REFERER" => "http://www.example.com/profile/edit" } }
      .to have_enqueued_job(AvatarUndoCleanupJob).with(middle.blob_id)
    expect(response).to redirect_to("/profile/edit")
    expect(album_blobs).to eq([ blobs[0], blobs[2] ])
    expect(ActiveStorage::Blob.exists?(middle.blob_id)).to be(true) # guardada para o Desfazer

    follow_redirect!
    toast = Nokogiri::HTML(response.body).at_css(".tt-toast--photo")
    expect(toast.at_css(".tt-title").text).to eq("Foto removida")
    expect(toast.at_css(".tt-text").text).to eq("Você ainda tem #{left} fotos no perfil.")
    expect(toast.at_css("form.tt-action-form")["action"]).to eq("/album_photos/undo")

    post "/album_photos/undo"
    expect(response).to redirect_to("/profile/edit")
    expect(album_blobs).to eq(blobs) # mesma ordem de antes
    follow_redirect!
    expect(Nokogiri::HTML(response.body).at_css(".tt-toast--photo .tt-title").text).to eq("Foto de volta")
  end

  it "o X não tem mais a confirmação (o Desfazer cuida disso)" do
    get "/profile/edit"
    link = Nokogiri::HTML(response.body).at_css("a.pe-photo-remove")
    expect(link["data-turbo-method"]).to eq("delete")
    expect(link["data-turbo-confirm"]).to be_nil
  end

  it "depois do prazo não desfaz e a limpeza apaga o arquivo; álbum cheio não deixa voltar" do
    first = me.album_photos_attachments.first
    delete "/album_photos/#{first.id}"

    travel(AlbumPhotosController::UNDO_WINDOW + 1.minute) do
      post "/album_photos/undo"
      expect(flash[:alert]).to eq("Não dá mais para desfazer a remoção da foto.")
      AvatarUndoCleanupJob.perform_now(first.blob_id)
    end
    expect(ActiveStorage::Blob.exists?(first.blob_id)).to be(false)

    second = me.reload.album_photos_attachments.first
    delete "/album_photos/#{second.id}"
    %w[clara.png bloco-upgrade.png botao-ajuda.png appstore.png].each do |name|
      me.album_photos.attach(io: File.open(img.join(name)), filename: name, content_type: "image/png")
    end
    post "/album_photos/undo"
    expect(flash[:alert]).to include("Seu álbum está cheio")
  end

  it "não remove foto de outra pessoa" do
    other = create(:user)
    other.album_photos.attach(io: File.open(img.join("clara.png")), filename: "c.png", content_type: "image/png")

    delete "/album_photos/#{other.album_photos_attachments.first.id}"

    expect(other.reload.album_photos.count).to eq(1)
    expect(flash[:alert]).to be_present
  end
end
