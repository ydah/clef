# frozen_string_literal: true

RSpec.describe Clef::Core::KeySignature do
  it "returns accidentals for major key" do
    key_signature = described_class.new(Clef::Core::Pitch.new(:a, 4), :major)

    expect(key_signature.accidentals).to eq({ count: 3, type: :sharp })
  end

  it "supports symbol tonic" do
    key_signature = described_class.new(:f, :major)

    expect(key_signature.accidentals).to eq({ count: 1, type: :flat })
  end
end
