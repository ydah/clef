# frozen_string_literal: true

RSpec.describe Clef::Core::Voice do
  it "adds elements and computes total length" do
    voice = described_class.new
    voice.add(Clef::Core::Note.new(Clef::Core::Pitch.new(:c, 4), Clef::Core::Duration.quarter))
    voice.add(Clef::Core::Rest.new(Clef::Core::Duration.quarter))

    expect(voice.elements.length).to eq(2)
    expect(voice.total_length).to eq(Rational(1, 2))
  end

  it "does not expose the mutable element store" do
    voice = described_class.new
    note = Clef::Core::Note.new(Clef::Core::Pitch.new(:c, 4), Clef::Core::Duration.quarter)
    voice.add(note)

    expect(voice.elements).to be_frozen
    expect do
      voice.elements << "quarter"
    end.to raise_error(FrozenError)
    expect(voice.elements).to eq([note])
  end

  it "rejects non-musical elements" do
    voice = described_class.new

    expect { voice.add("quarter") }.to raise_error(ArgumentError, /musical element/)
  end
end
