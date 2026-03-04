# frozen_string_literal: true

RSpec.describe Clef::Layout::Stem do
  it "points stem down for notes above B4" do
    note = Clef::Core::Note.new(Clef::Core::Pitch.new(:c, 5), Clef::Core::Duration.quarter)

    expect(described_class.direction(note, Clef::Core::Clef.new(:treble))).to eq(:down)
  end
end
