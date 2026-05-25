# frozen_string_literal: true

RSpec.describe Clef::Core::Chord do
  it "keeps input pitch order and exposes sorted pitches" do
    g4 = Clef::Core::Pitch.new(:g, 4)
    c4 = Clef::Core::Pitch.new(:c, 4)
    e4 = Clef::Core::Pitch.new(:e, 4)

    chord = described_class.new([g4, c4, e4], Clef::Core::Duration.quarter)

    expect(chord.pitches).to eq([g4, c4, e4])
    expect(chord.sorted_pitches).to eq([c4, e4, g4])
  end

  it "keeps the pitch collection immutable after validation" do
    chord = described_class.new([Clef::Core::Pitch.new(:c, 4)], Clef::Core::Duration.quarter)

    expect(chord.pitches).to be_frozen
    expect do
      chord.pitches << Clef::Core::Pitch.new(:d, 4)
    end.to raise_error(FrozenError)
  end

  it "rejects duplicate pitches" do
    c4 = Clef::Core::Pitch.new(:c, 4)

    expect do
      described_class.new([c4, c4], Clef::Core::Duration.quarter)
    end.to raise_error(ArgumentError, /duplicates/)
  end

  it "rejects duplicate sounding pitches from separate objects" do
    c_sharp = Clef::Core::Pitch.new(:c, 4, alteration: 1)
    d_flat = Clef::Core::Pitch.new(:d, 4, alteration: -1)

    expect do
      described_class.new([c_sharp, d_flat], Clef::Core::Duration.quarter)
    end.to raise_error(ArgumentError, /duplicates/)
  end
end
