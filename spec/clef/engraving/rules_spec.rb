# frozen_string_literal: true

RSpec.describe Clef::Engraving::Rules do
  it "defines engraving constants in expected range" do
    expect(described_class::STEM_LENGTH).to be_between(2.0, 6.0)
    expect(described_class::BEAM_THICKNESS).to be_between(0.2, 1.0)
    expect(described_class::MIN_NOTE_SPACING).to be_between(1.0, 3.0)
  end
end
