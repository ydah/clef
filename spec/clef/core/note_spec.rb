# frozen_string_literal: true

RSpec.describe Clef::Core::Note do
  let(:pitch) { Clef::Core::Pitch.new(:c, 4) }
  let(:duration) { Clef::Core::Duration.quarter }

  it "stores pitch and duration" do
    note = described_class.new(pitch, duration)

    expect(note.pitch).to eq(pitch)
    expect(note.duration).to eq(duration)
    expect(note.length).to eq(Rational(1, 4))
  end

  it "supports articulations and tie flag" do
    note = described_class.new(pitch, duration, articulations: [:staccato], tied: true)

    note.articulations << :accent

    expect(note.articulations).to include(:staccato, :accent)
    expect(note.tied).to be(true)
  end
end
