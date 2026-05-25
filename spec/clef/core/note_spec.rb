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
    expect(note.tie_state).to eq(:start)
  end

  it "supports explicit tie states" do
    note = described_class.new(pitch, duration, tied: :stop)

    expect(note.tied).to be(true)
    expect(note.tie_state).to eq(:stop)
  end

  it "rejects unknown articulations" do
    expect do
      described_class.new(pitch, duration, articulations: [:unknown])
    end.to raise_error(ArgumentError, /unsupported articulations/)
  end
end
