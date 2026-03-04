# frozen_string_literal: true

RSpec.describe Clef::Core::Clef do
  it "provides reference pitch and line" do
    clef = described_class.new(:treble)

    expect(clef.reference_pitch).to eq(Clef::Core::Pitch.new(:b, 4))
    expect(clef.reference_line).to eq(2)
  end
end
