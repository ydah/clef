# frozen_string_literal: true

RSpec.describe "notation classes" do
  it "creates barline symbols" do
    barline = Clef::Notation::Barline.new(:repeat_both)

    expect(barline.to_symbol).to eq(":|.|:")
  end

  it "parses lyric syllables" do
    lyric = Clef::Notation::Lyric.new(:voice1, "la-la _ -- lu")

    expect(lyric.syllables).to eq(%w[la la _ -- lu])
    expect(lyric.note_slot_count).to eq(4)
  end

  it "validates ties with same pitch" do
    c4 = Clef::Core::Pitch.new(:c, 4)
    note1 = Clef::Core::Note.new(c4, Clef::Core::Duration.quarter)
    note2 = Clef::Core::Note.new(Clef::Core::Pitch.new(:c, 4), Clef::Core::Duration.quarter)

    expect(Clef::Notation::Tie.new(note1, note2)).to be_a(Clef::Notation::Tie)
  end

  it "treats dynamics as zero-length markings" do
    dynamic = Clef::Notation::Dynamic.new(:mf)

    expect(dynamic.length).to eq(Rational(0, 1))
  end
end
