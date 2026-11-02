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
      expect(page.css("a.pe-tab").map { |tab| [ tab.text, tab["href"] ] })
        .to eq([ [ "Editar", "/profile/edit" ], [ "Pré-visualizar", "/profile/preview" ] ])
      expect(page.at_css("a.pe-tab.is-active").text).to eq("Editar")
      expect(page.at_css('[data-tab="preview"]')["hidden"]).not_to be_nil
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

  describe "GET /profile/preview (aba Pré-visualizar)" do
    def open_preview(user)
      sign_in user, scope: :user
      get "/profile/preview"
      expect(response).to have_http_status(:ok)
      Nokogiri::HTML(response.body)
    end

    it "abre a mesma tela já na prévia, com o cartão e as dicas" do
      attach_album(user, "p2", "p3")
      user.update_columns(username: "Samuel Teste", birthdate: 26.years.ago.to_date - 1.day, verified: true,
                          city: "Salvador", state: "BA")

      page = open_preview(user)

      expect(page.at_css("a.pe-tab.is-active").text).to eq("Pré-visualizar")
      expect(page.at_css('[data-tab="edit"]')["hidden"]).not_to be_nil
      expect(page.at_css('[data-tab="preview"]')["hidden"]).to be_nil
      expect(page.at_css('input[name="return_tab"]')["value"]).to eq("preview")

      card = page.at_css(".pv-card")
      expect(card.css(".pc-slide").size).to eq(2) # o mesmo carrossel do swipe
      expect(card.at_css(".pv-name strong").text).to eq("Samuel")
      expect(card.at_css(".pv-name span").text).to eq("26")
      expect(card.at_css(".pv-verified")).to be_present
      expect(card.at_css(".pv-place").text.squish).to eq("~200 m de você · Salvador")
      expect(card.at_css(".pv-bio").text).to eq("Sou advogado.")
      expect(card.css(".pv-tags li").map(&:text)).to eq(%w[Praia Culinária Fitness])
      expect(page.css(".pv-actions button[disabled]").size).to eq(3)

      tips = page.css(".pv-tips li").map { |tip| [ tip["class"], tip.at_css("span").text, tip.at_css("a")&.[]("href") ] }
      expect(tips).to eq([
        [ "is-todo", "2 de 6 fotos adicionadas", "/profile/edit#pe-fotos" ],
        [ "is-done", "Identidade verificada", nil ],
        [ "is-todo", "Escolha quem você quer conhecer", "/profile/edit#pe-interested-in" ]
      ])
    end

    it "sem verificação: a dica leva para a verificação" do
      page = open_preview(user)

      tip = page.css(".pv-tips li").find { |item| item.text.include?("Verifique sua identidade") }
      expect(tip.at_css("a")["href"]).to eq("/verificacao")
    end
  end

  describe "PATCH" do
    before { sign_in user, scope: :user }

    it "grava os interesses enviados como lista (sem repetidos)" do
      patch "/profile", params: { user: { hobbies_list: [ "", "Praia", " Cinema ", "praia" ] } }

      expect(response).to redirect_to(edit_profile_path)
      expect(user.reload.hobbies_list).to eq(%w[Praia Cinema])
    end

    it "salvando na aba Pré-visualizar, volta para ela" do
      patch "/profile", params: { return_tab: "preview", user: { bio: "Nova bio" } }

      expect(response).to redirect_to(preview_profile_path)
      expect(user.reload.bio).to eq("Nova bio")
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
