# frozen_string_literal: true

RSpec.describe Clef::Engraving::GlyphTable do
  it "fetches glyph by name" do
    table = described_class.new

    expect(table.fetch(:notehead_black)).to be_a(String)
    expect(table.key?(:accidental_sharp)).to be(true)
  end

  it "allows plugins to register glyphs" do
    table = described_class.new

    table.register(:custom, "x")

    expect(table[:custom]).to eq("x")
  end
end
