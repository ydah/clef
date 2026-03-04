# frozen_string_literal: true

RSpec.describe Clef::Core::Voice do
  it "adds elements and computes total length" do
    voice = described_class.new
    voice.add(Clef::Core::Note.new(Clef::Core::Pitch.new(:c, 4), Clef::Core::Duration.quarter))
    voice.add(Clef::Core::Rest.new(Clef::Core::Duration.quarter))

    expect(voice.total_length).to eq(Rational(1, 2))
  end
end
