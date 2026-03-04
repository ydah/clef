# frozen_string_literal: true

RSpec.describe Clef::Core::Pitch do
  describe "initialization" do
    it "supports 7 note names x 5 accidentals" do
      notes = %i[c d e f g a b]
      alterations = [-2, -1, 0, 1, 2]

      notes.product(alterations).each do |note_name, alteration|
        pitch = described_class.new(note_name, 4, alteration: alteration)
        expect(pitch.note_name).to eq(note_name)
        expect(pitch.alteration).to eq(alteration)
      end
    end

    it "rejects invalid note name" do
      expect { described_class.new(:h, 4) }.to raise_error(ArgumentError)
      expect { described_class.new(nil, 4) }.to raise_error(ArgumentError)
    end
  end

  describe "pitch conversions" do
    it "converts to midi number" do
      expect(described_class.new(:c, 4).to_midi).to eq(60)
      expect(described_class.new(:a, 4).to_midi).to eq(69)
      expect(described_class.new(:c, 4, alteration: 1).to_midi).to eq(61)
      expect(described_class.new(:b, 3, alteration: -1).to_midi).to eq(58)
    end

    it "converts to frequency" do
      expect(described_class.new(:a, 4).to_frequency).to be_within(0.0001).of(440.0)
    end
  end

  describe "operations" do
    it "transposes by semitones" do
      transposed = described_class.new(:c, 4).transpose(7)
      expect(transposed).to eq(described_class.new(:g, 4))
    end

    it "checks enharmonic equivalence" do
      c_sharp = described_class.new(:c, 4, alteration: 1)
      d_flat = described_class.new(:d, 4, alteration: -1)

      expect(c_sharp.enharmonic?(d_flat)).to be(true)
    end

    it "compares by semitone position" do
      c4 = described_class.new(:c, 4)
      d4 = described_class.new(:d, 4)
      c_sharp = described_class.new(:c, 4, alteration: 1)
      d_flat = described_class.new(:d, 4, alteration: -1)

      expect(c4).to be < d4
      expect([d4, c_sharp, d_flat].sort.first).to eq(c_sharp)
    end
  end

  describe "lilypond conversion" do
    it "roundtrips with parse" do
      original = described_class.new(:f, 5, alteration: 1)
      parsed = described_class.parse(original.to_lilypond)

      expect(parsed).to eq(original)
    end

    it "parses sample notation" do
      expect(described_class.parse("c'")).to eq(described_class.new(:c, 4))
      expect(described_class.parse("fis''")).to eq(described_class.new(:f, 5, alteration: 1))
    end

    it "rejects invalid lilypond string" do
      expect { described_class.parse("z#4") }.to raise_error(ArgumentError)
    end
  end
end
