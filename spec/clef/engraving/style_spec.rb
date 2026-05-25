# frozen_string_literal: true

RSpec.describe Clef::Engraving::Style do
  it "provides default values" do
    style = described_class.default

    expect(style.page_size).to eq("A4")
    expect(style.staff_space).to be > 0
    expect(style.min_note_spacing).to eq(Clef::Engraving::Rules::MIN_NOTE_SPACING * style.staff_space)
    expect(style.beam_thickness).to eq(Clef::Engraving::Rules::BEAM_THICKNESS * style.staff_space)
  end

  it "allows concrete drawing values to override rule-derived defaults" do
    style = described_class.new(min_note_spacing: 24, beam_thickness: 4)

    expect(style.min_note_spacing).to eq(24)
    expect(style.beam_thickness).to eq(4)
  end
end
