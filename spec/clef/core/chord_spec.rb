# frozen_string_literal: true

RSpec.describe Clef::Core::Chord do
  it "sorts pitches from low to high" do
    g4 = Clef::Core::Pitch.new(:g, 4)
    c4 = Clef::Core::Pitch.new(:c, 4)
    e4 = Clef::Core::Pitch.new(:e, 4)

    chord = described_class.new([g4, c4, e4], Clef::Core::Duration.quarter)

    expect(chord.pitches).to eq([c4, e4, g4])
  end
end
