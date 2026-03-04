# frozen_string_literal: true

RSpec.describe Clef::Engraving::Style do
  it "provides default values" do
    style = described_class.default

    expect(style.page_size).to eq("A4")
    expect(style.staff_space).to be > 0
    expect(style.min_note_spacing).to be > 0
  end
end
