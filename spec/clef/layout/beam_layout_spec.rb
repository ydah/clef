# frozen_string_literal: true

RSpec.describe Clef::Layout::BeamLayout do
  def eighth_notes(count)
    Array.new(count) do
      Clef::Core::Note.new(Clef::Core::Pitch.new(:c, 4), Clef::Core::Duration.eighth)
    end
  end

  it "auto-beams 4/4 in groups of four eighth notes" do
    groups = described_class.auto_beam(eighth_notes(8), Clef::Core::TimeSignature.new(4, 4))

    expect(groups.map(&:length)).to eq([4, 4])
  end

  it "auto-beams 6/8 in groups of three eighth notes" do
    groups = described_class.auto_beam(eighth_notes(6), Clef::Core::TimeSignature.new(6, 8))

    expect(groups.map(&:length)).to eq([3, 3])
  end
end
