# frozen_string_literal: true

RSpec.describe Clef::Core::Tempo do
  it "stores beat unit and bpm" do
    tempo = described_class.new(beat_unit: Clef::Core::Duration.quarter, bpm: 108)

    expect(tempo.bpm).to eq(108)
    expect(tempo.beat_unit).to eq(Clef::Core::Duration.quarter)
  end
end
