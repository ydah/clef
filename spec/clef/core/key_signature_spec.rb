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

  it "supports lilypond-style accidental tonic symbols" do
    expect(described_class.new(:fis, :major).accidentals).to eq({ count: 6, type: :sharp })
    expect(described_class.new(:bes, :major).accidentals).to eq({ count: 2, type: :flat })
  end

  it "raises for unsupported keys instead of falling back to natural" do
    key_signature = described_class.new(:gis, :major)

    expect { key_signature.accidentals }.to raise_error(ArgumentError, /unsupported major key tonic/)
  end
end
