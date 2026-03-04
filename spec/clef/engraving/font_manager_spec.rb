# frozen_string_literal: true

RSpec.describe Clef::Engraving::FontManager do
  it "falls back to Helvetica when font file is missing" do
    manager = described_class.new(font_path: "/nonexistent/font.otf")
    pdf = instance_double("Prawn::Document", font_families: {}, font: nil)

    expect(manager.register_with(pdf)).to eq("Helvetica")
  end
end
