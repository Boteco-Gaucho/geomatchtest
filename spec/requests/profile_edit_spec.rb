require "rails_helper"

RSpec.describe "Editar Perfil (/profile/edit)", type: :request do
  # Sem cidade/estado na criação: com endereço o Geocoder consultaria o Nominatim
  let(:user) do
    create(:user, onboarding_completed: true, gender: "Homem", interested_in: nil,
                  bio: "Sou advogado.", hobbies: "Praia,Culinária,Fitness")
  end

  def attach_album(user, *names)
    names.each { |name| user.album_photos.attach(io: StringIO.new(name), filename: "#{name}.jpg", content_type: "image/jpeg") }
  end

  def album_filenames(user)
    user.reload.album_photos.map { |photo| photo.filename.to_s }
  end

  def upload(name)
    Rack::Test::UploadedFile.new(StringIO.new(name), "image/jpeg", original_filename: "#{name}.jpg")
  end

  describe "GET" do
    def open_edit(user)
      sign_in user, scope: :user
      get "/profile/edit"
      expect(response).to have_http_status(:ok)
      Nokogiri::HTML(response.body)
    end

    it "monta fotos, selo, bio, sobre você, local e interesses do mockup" do
      attach_album(user, "p2", "p3")
      user.update_columns(city: "Salvador", state: "BA") # depois do attach, que salva o usuário

      page = open_edit(user)

      expect(page.at_css("img.pe-title-img")["src"]).to include("texto-editar-perfil") # título continua o PNG dourado
      expect(page.at_css("a.pe-tab")["href"]).to eq("/profile/preview")
      # Sem foto principal de verdade (só o avatar padrão): 2 do álbum ocupadas
      expect(page.at_css(".pe-section-meta").text).to eq("2 de 6 · segure e arraste para reordenar")
      expect(page.css(".pe-photo-placeholder")).to be_present
      expect(page.css('input[name="user[album_order][]"]').size).to eq(2)
      expect(page.css(".pe-photo-number").map(&:text)).to eq(%w[2 3])
      expect(page.css("label.pe-photo--add").size).to eq(3)

      expect(page.at_css(".pe-verify h3").text).to eq("Ganhe o selo de verificado")
      expect(page.at_css("a.pe-verify-btn")["href"]).to eq("/verificacao")

      expect(page.at_css("textarea#user_bio")["maxlength"]).to eq("300")
      expect(page.at_css('[data-char-counter-target="count"]').text).to eq("13/300")
      expect(page.at_css(".pe-tip").text.squish).to end_with("como seu lugar favorito em Salvador.")

      expect(page.css('input[name="user[gender]"]').map { |radio| radio["value"] })
        .to eq([ "Homem", "Mulher", "Não Binário", "Outro" ])
      expect(page.at_css('input[name="user[gender]"][checked]')["value"]).to eq("Homem")
      expect(page.css('input[name="user[interested_in]"][checked]')).to be_empty
      expect(page.css(".pe-warning").size).to eq(1) # só "Quero conhecer" está vazio

      expect(page.at_css("select#user_state option[selected]")["value"]).to eq("BA")
      expect(page.at_css("input#user_city")["value"]).to eq("Salvador")

      expect(page.css(".pe-interests .pe-interest-name").map(&:text)).to eq(%w[Praia Culinária Fitness])
      expect(page.at_css('[data-interests-target="count"]').text).to eq("3 de 8")
      expect(page.css(".pe-suggestion:not([hidden])").map { |chip| chip.text.squish })
        .to eq([ "+ Viagens", "+ Música ao vivo", "+ Carnaval", "+ Futebol" ])
    end

    it "perfil verificado: troca o convite pelo selo" do
      user.update_columns(verified: true)

      page = open_edit(user)

      expect(page.at_css(".pe-verify--done h3").text).to eq("Perfil verificado")
      expect(page.css("a.pe-verify-btn")).to be_empty
    end

    it "verificação em análise: sem botão de enviar de novo" do
      user.update_columns(ai_moderation_status: "pending")

      page = open_edit(user)

      expect(page.at_css(".pe-verify h3").text).to eq("Verificação em análise")
      expect(page.css("a.pe-verify-btn")).to be_empty
    end

    it "verificação recusada: mostra o motivo e o reenvio" do
      user.update_columns(ai_moderation_status: "rejected", ai_moderation_details: { "reason" => "face_mismatch" })

      page = open_edit(user)

      expect(page.at_css(".pe-verify p").text).to include("O rosto da selfie não corresponde ao documento.")
      expect(page.at_css("a.pe-verify-btn").text.squish).to eq("Enviar novas fotos")
    end
  end

  describe "PATCH" do
    before { sign_in user, scope: :user }

    it "grava os interesses enviados como lista (sem repetidos)" do
      patch "/profile", params: { user: { hobbies_list: [ "", "Praia", " Cinema ", "praia" ] } }

      expect(response).to redirect_to(edit_profile_path)
      expect(user.reload.hobbies_list).to eq(%w[Praia Cinema])
    end

    it "remover todos os interesses também é salvo" do
      patch "/profile", params: { user: { hobbies_list: [ "" ] } }

      expect(user.reload.hobbies_list).to be_empty
    end

    it "aceita o gênero \"Outro\"" do
      patch "/profile", params: { user: { gender: "Outro" } }

      expect(user.reload.gender).to eq("Outro")
    end

    it "aplica a nova ordem do álbum (segurar e arrastar)" do
      attach_album(user, "p2", "p3", "p4")
      first, second, third = user.album_photos_attachments.pluck(:id)

      patch "/profile", params: { user: { bio: "Nova bio", album_order: [ third, first, second ] } }

      expect(album_filenames(user)).to eq(%w[p4 p2 p3].map { |name| "#{name}.jpg" })
      expect(user.bio).to eq("Nova bio")
    end

    it "ignora fotos de outra pessoa na ordem do álbum" do
      other = create(:user)
      attach_album(other, "alheia")
      attach_album(user, "p2", "p3")
      first, second = user.album_photos_attachments.pluck(:id)

      patch "/profile", params: { user: { album_order: [ other.album_photos_attachments.first.id, second, first ] } }

      expect(album_filenames(user)).to eq(%w[p3.jpg p2.jpg])
      expect(album_filenames(other)).to eq(%w[alheia.jpg])
    end

    it "fotos novas só até completar as 6 posições" do
      attach_album(user, "p2", "p3", "p4", "p5")

      patch "/profile", params: { user: { album_photos: [ upload("nova1"), upload("nova2") ] } }

      expect(album_filenames(user)).to eq(%w[p2 p3 p4 p5 nova1].map { |name| "#{name}.jpg" })
      expect(flash[:alert]).to eq("Você pode ter até 6 fotos. Remova uma para adicionar outra.")
    end
  end
end
