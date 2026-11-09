require "rails_helper"

# Filtros da tela de início (/lead) — folha "Filtros", LeadFilters e AdvancedDiscoveryService
RSpec.describe "Filtros do /lead", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  # Coordenadas sem endereço: o Geocoder não consulta o Nominatim
  let(:me) { create(:user, onboarding_completed: true, plan: free_plan, interested_in: "Mulher", latitude: -12.9714, longitude: -38.5014) }

  def person(attrs = {})
    create(:user, { onboarding_completed: true, plan: free_plan, gender: "Mulher",
                    birthdate: 26.years.ago.to_date - 20.days, latitude: -12.9705, longitude: -38.5014 }.merge(attrs))
  end

  def discover(filters)
    AdvancedDiscoveryService.new(me).find_next_eligible_user([], LeadFilters.new(filters, me).to_discovery).first
  end

  describe "LeadFilters" do
    it "padrões: gênero do \"Quero conhecer\" do perfil, 500 km, ampliar ligado, 18–60, nada mais" do
      lf = LeadFilters.defaults(me)

      expect(lf.genders).to eq([ "mulheres" ])
      expect([ lf.distance, lf.expand, lf.min_age, lf.max_age ]).to eq([ 500, true, 18, 60 ])
      expect([ lf.interests, lf.online, lf.verified, lf.with_bio ]).to eq([ [], false, false, false ])
      expect(lf.active_count).to eq(0)
    end

    it "conta como ativo o que difere do padrão (o exemplo do mockup dá 3 + gênero trocado)" do
      lf = LeadFilters.new({ "genders" => %w[mulheres], "distance" => "500", "min_age" => "18", "max_age" => "60",
                             "interests" => %w[praia viagem], "verified" => "1" }, me)
      expect(lf.active_count).to eq(2) # interesses + verificados

      lf = LeadFilters.new({ "genders" => %w[homens], "distance" => "80", "min_age" => "25", "max_age" => "40",
                             "online" => "1", "with_bio" => "1" }, me)
      expect(lf.active_count).to eq(5)
    end

    it "limpa valores inválidos (fora da faixa, chaves desconhecidas, idades trocadas)" do
      lf = LeadFilters.new({ "genders" => %w[mulheres xyz], "distance" => "9999", "min_age" => "70", "max_age" => "20",
                             "interests" => %w[praia hackear] }, me)

      expect(lf.genders).to eq([ "mulheres" ])
      expect(lf.distance).to eq(500)
      expect([ lf.min_age, lf.max_age ]).to eq([ 20, 70 ])
      expect(lf.interests).to eq([ "praia" ])
    end
  end

  describe "AdvancedDiscoveryService com os filtros" do
    it "Quero conhecer: só os gêneros marcados; nenhum marcado = todos" do
      homem = person(gender: "Homem")
      expect(discover("genders" => %w[mulheres])).to be_nil
      expect(discover("genders" => %w[homens])).to eq(homem)
      expect(discover("genders" => [])).to eq(homem)
    end

    it "só verificados, com bio e online agora" do
      plain = person
      expect(discover("verified" => "1")).to be_nil
      plain.update_columns(verified: true)
      expect(discover("verified" => "1")).to eq(plain)

      expect(discover("with_bio" => "1")).to be_nil
      plain.update_columns(bio: "Oi!")
      expect(discover("with_bio" => "1")).to eq(plain)

      plain.update_columns(last_seen_at: 1.hour.ago)
      expect(discover("online" => "1")).to be_nil
      plain.update_columns(last_seen_at: Time.current)
      expect(discover("online" => "1")).to eq(plain)
    end

    it "interesses em comum: casa os chips com os interesses do perfil (texto livre, sem acento)" do
      viajante = person(hobbies: "Viagens,Culinária")
      expect(discover("interests" => %w[praia])).to be_nil
      expect(discover("interests" => %w[viagem])).to eq(viajante)
      expect(discover("interests" => %w[gastronomia])).to eq(viajante)
    end

    it "faixa etária e distância; ampliar busca mais longe quando acaba" do
      longe = person(birthdate: 30.years.ago.to_date - 20.days, latitude: -12.0, longitude: -38.5014) # ~108 km
      expect(discover("min_age" => "35", "max_age" => "50", "distance" => "500")).to be_nil
      expect(discover("distance" => "20", "expand" => "0")).to be_nil
      expect(discover("distance" => "20", "expand" => "1")).to eq(longe)
    end
  end

  describe "aplicar e limpar" do
    before { sign_in me, scope: :user }

    it "a folha mostra os padrões e os gêneros/interesses do mockup" do
      get "/lead"
      page = Nokogiri::HTML(response.body)

      expect(page.at_css(".lf-title").text).to eq("Filtros")
      expect(page.at_css(".lf-active").key?("hidden")).to be(true)
      expect(page.css(".lf-card-title").map(&:text))
        .to eq([ "Quero conhecer", "Distância máxima", "Faixa etária", "Interesses em comum", "Mais filtros" ])
      expect(page.css('input[name="f[genders][]"][type=checkbox]').map { |i| [ i["value"], i.key?("checked") ] })
        .to eq([ [ "mulheres", true ], [ "homens", false ], [ "nao_binario", false ] ])
      expect(page.css(".lf-chip--plain span").map(&:text)).to eq(%w[Praia Viagem Cinema Música Academia Gastronomia Leitura Balada])
      expect(page.at_css('input[name="f[distance]"]')["value"]).to eq("500")
      expect(page.at_css('input[name="f[min_age]"]')["value"]).to eq("18")
      expect(page.at_css('input[name="f[max_age]"]')["value"]).to eq("60")
      expect(page.css(".lf-row-text strong").map(&:text))
        .to eq([ "Ampliar se acabarem os perfis", "Online agora", "Só perfis verificados", "Com bio preenchida" ])
      expect(page.at_css("a.lf-clear")["href"]).to eq("/lead?limpar_filtros=1")
      expect(page.at_css("button.lf-apply").text).to eq("Aplicar filtros")
    end

    it "Aplicar grava na sessão, volta para /lead e os filtros continuam depois de rejeitar" do
      get "/lead", params: { f: { genders: [ "", "homens" ], distance: "80", expand: "0", min_age: "25", max_age: "40",
                                  interests: %w[praia], online: "0", verified: "1", with_bio: "0" } }
      expect(response).to redirect_to(lead_path)

      follow_redirect!
      page = Nokogiri::HTML(response.body)
      expect(page.at_css(".lf-active").text.squish).to eq("5 ativos") # gênero, distância, idade, interesses, verificados
      expect(page.at_css('input[value="homens"]').key?("checked")).to be(true)
      expect(page.at_css('input[name="f[distance]"]')["value"]).to eq("80")
      expect(page.at_css('input[value="praia"]').key?("checked")).to be(true)

      # Rejeitar busca o próximo com os filtros guardados
      expect_any_instance_of(AdvancedDiscoveryService).to receive(:find_next_eligible_user)
        .with(anything, hash_including(distance: 80, genders: [ "homem" ], verified: true, interest_terms: [ "praia" ]))
        .and_return([ nil, nil ])
      other = person
      post "/lead/reject", params: { user_id: other.id }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    it "Limpar volta tudo ao padrão" do
      get "/lead", params: { f: { genders: [ "" ], verified: "1" } }
      get "/lead", params: { limpar_filtros: 1 }
      expect(response).to redirect_to(lead_path)
      follow_redirect!

      page = Nokogiri::HTML(response.body)
      expect(page.at_css(".lf-active").key?("hidden")).to be(true)
      expect(page.at_css('input[value="mulheres"]').key?("checked")).to be(true)
      expect(page.at_css('input[name="f[verified]"][type=checkbox]').key?("checked")).to be(false)
    end
  end

  describe "acabaram os perfis" do
    before { sign_in me, scope: :user }

    it "sem ajustes: mensagem, sem chips, Ajustar filtros e o mapa; sem número no botão" do
      get "/lead"
      page = Nokogiri::HTML(response.body)
      empty = page.at_css(".le-empty")

      expect(empty.at_css(".le-title").text).to eq("Novas pessoas estão a caminho")
      expect(empty.at_css(".le-text").text).to include("amplie seus filtros ou espie quem está no mapa agora")
      expect(empty.at_css(".le-chips")).to be_nil
      expect(empty.at_css("button.le-adjust")["data-action"]).to eq("filters#open")
      expect(empty.at_css("a.le-map")["href"]).to eq("/discover_3d")
      expect(empty.at_css("a.le-map").text.squish).to eq("Ver quem está no mapa agora")
      expect(page.at_css(".lead-filter-btn .lead-filter-count")).to be_nil
    end

    it "os filtros ajustados aparecem em chips e o número do botão é a quantidade deles" do
      get "/lead", params: { f: { genders: [ "", "mulheres", "homens" ], min_age: "25", max_age: "40", distance: "80",
                                  interests: %w[praia viagem], verified: "1" } }
      follow_redirect!
      page = Nokogiri::HTML(response.body)

      chips = page.css(".le-chips li").map(&:text)
      expect(chips).to eq([ "Mulheres e Homens", "25 – 40 anos", "até 80 km", "2 interesses", "Verificados" ])
      expect(page.at_css(".lead-filter-count").text).to eq("5")
      expect(page.at_css(".lf-active").text.squish).to eq("5 ativos")
    end

    it "rejeitar o último perfil mostra o mesmo fim, com os chips da sessão" do
      get "/lead", params: { f: { genders: [ "" ], verified: "1" } }
      last = person(verified: true)
      post "/lead/reject", params: { user_id: last.id }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include("Novas pessoas estão a caminho")
      expect(response.body).to include("<li>Todos os gêneros</li>")
      expect(response.body).to include("<li>Verificados</li>")
    end
  end
end

