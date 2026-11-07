require "rails_helper"

# Salvar a edição do perfil (PATCH /profile) → aviso "Perfil atualizado" no topo
# (shared/_profile_saved_toast, componente shared/_top_toast)
RSpec.describe "Aviso de perfil atualizado", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let(:user) { create(:user, onboarding_completed: true, plan: free_plan) }

  before { sign_in user, scope: :user }

  it "volta para a edição com o aviso do mockup, uma vez só" do
    patch "/profile", params: { user: { bio: "Gosto de café e de trilhas." } }
    expect(response).to redirect_to(edit_profile_path)
    expect(user.reload.bio).to eq("Gosto de café e de trilhas.")

    follow_redirect!
    page = Nokogiri::HTML(response.body)
    toast = page.at_css(".tt-toast.tt-toast--saved")
    expect(toast["data-controller"]).to eq("top-toast")
    expect(toast["data-top-toast-duration-value"]).to eq("5000")
    expect(toast.at_css(".tt-icon--success svg")).to be_present
    expect(toast.at_css(".tt-title").text).to eq("Perfil atualizado")
    expect(toast.at_css(".tt-text").text).to eq("Quem está por perto já vê suas novidades.")
    expect(toast.at_css("button.tt-close")["aria-label"]).to eq("Fechar aviso")
    expect(toast.at_css(".tt-bar")).to be_nil
    expect(page.at_css("#toast-container .toast")).to be_nil # sem o aviso antigo "Perfil atualizado!"

    get "/profile/edit"
    expect(response.body).not_to include("tt-toast--saved")
  end

  it "salvando pela aba Pré-visualizar, volta para ela com o aviso" do
    patch "/profile", params: { user: { bio: "Oi" }, return_tab: "preview" }
    expect(response).to redirect_to(preview_profile_path)
    follow_redirect!

    expect(response.body).to include("Perfil atualizado")
  end
end
