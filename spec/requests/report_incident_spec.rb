require "rails_helper"

RSpec.describe "Fazer uma denúncia (/report_incident)", type: :request do
  let(:me)     { create(:user, username: "Samuel", onboarding_completed: true) }
  let(:felipe) { create(:user, username: "Felipe Alves") }
  let(:fany)   { create(:user, username: "Fany") }

  # PNG 1×1 de verdade (o Active Storage identifica o tipo pelo conteúdo)
  def png(name = "print.png")
    bytes = [ "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d4944415478da63f8cfc0f01f0005000201a0f5e1a40000000049454e44ae426082" ].pack("H*")
    file = Tempfile.new([ "print", ".png" ]).tap { |f| f.binmode; f.write(bytes); f.rewind }
    Rack::Test::UploadedFile.new(file.path, "image/png", true, original_filename: name)
  end

  before { sign_in me, scope: :user }

  describe "GET" do
    it "monta a tela do mockup com as pessoas das conversas em \"Sobre quem?\"" do
      Match.create!(user: me, matched_user: felipe)

      get "/report_incident"
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)

      expect(page.at_css(".sc-title").text).to eq("Fazer uma denúncia")
      expect(page.at_css(".sc-subtitle").text).to eq("Nossa equipe analisa cada relato com atenção.")
      expect(page.at_css(".sc-back")["href"]).to eq("/safety_center")
      expect(page.css(".ri-chip span").map(&:text))
        .to eq([ "Perfil falso", "Assédio", "Mensagens ofensivas", "Golpe ou pedido de dinheiro", "Encontro inseguro", "Outro" ])
      expect(page.css("input[name='report[category]'][checked]")).to be_empty # a pessoa escolhe
      expect(page.at_css(".ri-person-name").text).to eq("Escolher um perfil das suas conversas")
      expect(page.css(".ri-pick-name").map(&:text)).to eq([ "Não quero indicar um perfil", "Felipe Alves" ])
      expect(page.at_css("#report_description")["maxlength"]).to eq("1000")
      expect(page.at_css("#ri-photos-input")["name"]).to eq("report[photos][]")
      expect(page.at_css(".ri-notice").text.squish)
        .to eq("A pessoa denunciada não fica sabendo que foi você. Depois de enviada, a denúncia não pode ser editada.")
      expect(page.at_css("button.ri-submit").text).to eq("Enviar denúncia")
    end

    it "chega com a pessoa escolhida quando vem do chat/perfil (user_id), mesmo fora das conversas" do
      get "/report_incident", params: { user_id: fany.id }
      page = Nokogiri::HTML(response.body)

      expect(page.at_css(".ri-person-name").text).to eq("Fany")
      expect(page.at_css("input[name='report[reported_user_id]'][checked]")["value"]).to eq(fany.id.to_s)
    end

    it "ignora user_id do próprio perfil" do
      get "/report_incident", params: { user_id: me.id }

      expect(Nokogiri::HTML(response.body).at_css(".ri-person-name").text).to eq("Escolher um perfil das suas conversas")
    end

    it "sem a coluna nova em produção, esconde o \"Sobre quem?\" e continua funcionando" do
      allow(Report).to receive(:reported_user_column?).and_return(false)

      get "/report_incident", params: { user_id: fany.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Sobre quem?")
    end
  end

  describe "POST /reports" do
    it "salva categoria, relato, pessoa denunciada e fotos" do
      expect {
        post "/reports", params: { report: { category: "harassment", description: "Mensagens insistentes",
                                             reported_user_id: felipe.id, photos: [ "", png("a.png"), png("b.png") ] } }
      }.to change(Report, :count).by(1)

      expect(response).to redirect_to(safety_center_path)
      expect(flash[:notice]).to eq("Denúncia enviada. Nossa equipe vai analisar com atenção.")
      report = Report.last
      expect(report).to have_attributes(category: "harassment", description: "Mensagens insistentes",
                                        reporter: me, reported_user: felipe)
      expect(report.photos.map { |photo| photo.filename.to_s }).to eq(%w[a.png b.png])
    end

    it "sem relato: volta para a tela com o erro, mantendo o que foi escolhido" do
      post "/reports", params: { report: { category: "scam", description: "", reported_user_id: felipe.id } }

      expect(response).to have_http_status(:unprocessable_entity)
      page = Nokogiri::HTML(response.body)
      expect(page.at_css(".ri-errors").text.squish).to eq("Conte o que houve.")
      expect(page.at_css("input[name='report[category]'][checked]")["value"]).to eq("scam")
      expect(page.at_css(".ri-person-name").text).to eq("Felipe Alves")
    end

    it "não aceita denunciar o próprio perfil nem mais de 3 fotos" do
      post "/reports", params: { report: { category: "other", description: "Teste", reported_user_id: me.id,
                                           photos: Array.new(4) { |i| png("#{i}.png") } } }

      expect(response).to have_http_status(:unprocessable_entity)
      errors = Nokogiri::HTML(response.body).css(".ri-errors p").map(&:text)
      expect(errors).to include("Você não pode denunciar o próprio perfil.", "Envie no máximo 3 fotos.")
    end

    it "sem a coluna nova, ignora a pessoa e salva o resto" do
      allow(Report).to receive(:reported_user_column?).and_return(false)

      post "/reports", params: { report: { category: "fake_profile", description: "Fotos de outra pessoa", reported_user_id: felipe.id } }

      expect(response).to redirect_to(safety_center_path)
      expect(Report.last.reported_user_id).to be_nil
    end
  end

  it "exige login" do
    sign_out me

    get "/report_incident"

    expect(response).to redirect_to(new_user_session_path)
  end
end
