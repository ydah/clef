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
end
