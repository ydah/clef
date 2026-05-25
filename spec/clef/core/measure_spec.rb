# frozen_string_literal: true

RSpec.describe Clef::Core::Measure do
  it "detects overflow by time signature" do
    measure = described_class.new(1, time_signature: Clef::Core::TimeSignature.new(4, 4))
    voice = measure.voice

    5.times do
      voice.add(Clef::Core::Note.new(Clef::Core::Pitch.new(:c, 4), Clef::Core::Duration.quarter))
    end

    expect(measure.overflowing_voice_ids).to contain_exactly(:default)
  end

  it "detects underfull voices by time signature" do
    measure = described_class.new(1, time_signature: Clef::Core::TimeSignature.new(4, 4))
    measure.voice(:default).add(Clef::Core::Rest.new(Clef::Core::Duration.quarter))

    expect(measure.underfull_voice_ids).to eq([:default])
  end

  it "does not expose the mutable voice store" do
    measure = described_class.new(1)
    measure.voice(:default)

    expect(measure.voices).to be_frozen
    expect { measure.voices[:other] = Clef::Core::Voice.new(id: :other) }.to raise_error(FrozenError)
    expect(measure.voices.keys).to eq([:default])
  end
end
