require 'rails_helper'

RSpec.describe Report, type: :model do
  let(:reporter) { create(:user) }

  it "sem categoria vira \"other\"" do
    report = Report.create!(reporter: reporter, category: "", description: "Algo estranho")

    expect(report.category).to eq("other")
  end

  it "recusa categoria fora da lista" do
    report = Report.new(reporter: reporter, category: "spam_total", description: "x")

    expect(report).not_to be_valid
    expect(report.errors[:category]).to eq([ "Escolha o que aconteceu." ])
  end

  it "conta a quebra de linha como 1 caractere, como o maxlength do navegador" do
    text = "#{'a' * 499}\r\n#{'b' * 500}" # 1000 no campo, 1001 com \r\n

    report = Report.new(reporter: reporter, category: "other", description: text)

    expect(report).to be_valid
    expect(report.description.length).to eq(1000)
  end

  it "aceita \"Encontro inseguro\" (categoria nova)" do
    expect(Report::FORM_CATEGORIES.keys - Report::CATEGORIES).to be_empty
    expect(Report.new(reporter: reporter, category: "unsafe_date", description: "x")).to be_valid
  end
end
