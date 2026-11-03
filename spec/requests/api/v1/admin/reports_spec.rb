require "rails_helper"

RSpec.describe "Api::V1::Admin::Reports", type: :request do
  let!(:admin) { create(:user, admin: true) }
  let(:auth_headers) do
    { "Authorization" => "Bearer #{JwtService.encode({ sub: admin.id })}", "Accept" => "application/json" }
  end

  it "mostra quem foi denunciado (\"Sobre quem?\")" do
    reporter = create(:user, username: "Samuel")
    reported = create(:user, username: "Felipe Alves")
    Report.create!(reporter: reporter, reported_user: reported, category: "harassment", description: "Insistente")
    Report.create!(reporter: reporter, category: "other", description: "Sem perfil")

    get "/api/v1/admin/reports", headers: auth_headers

    expect(response).to have_http_status(:ok)
    by_text = response.parsed_body["reports"].index_by { |report| report["description"] }
    expect(by_text["Insistente"]["reported_user"]).to eq("id" => reported.id, "name" => "Felipe Alves")
    expect(by_text["Sem perfil"]["reported_user"]).to be_nil
    expect(response.parsed_body["by_category"]).to include("unsafe_date" => 0)
  end
end
