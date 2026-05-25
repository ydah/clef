# frozen_string_literal: true

RSpec.describe Clef::Parser::LilypondParser do
  it "parses basic lilypond syntax into score" do
    lilypond = <<~LY
      \\clef treble
      \\key c \\major
      \\time 4/4
      { c'4 d'4 e'4 f'4 }
    LY

    score = described_class.new.parse(lilypond)
    voice = score.staves.first.measures.first.voices[:default]

    expect(voice.elements.length).to eq(4)
    expect(score.staves.first.time_signature.measure_length).to eq(Rational(1, 1))
  end

  it "parses tempo, block comments, chords, and rests" do
    lilypond = <<~LY
      %{ hidden { c'1 } %}
      \\tempo 2 = 60
      \\clef bass
      \\key bes \\major
      \\time 4/4
      { <c e g>2 r2 }
    LY

    score = described_class.new.parse(lilypond)
    elements = score.staves.first.measures.first.voices[:default].elements

    expect(score.tempo.beat_unit.to_lilypond).to eq("2")
    expect(score.tempo.bpm).to eq(60)
    expect(score.staves.first.clef.type).to eq(:bass)
    expect(elements.map(&:class)).to eq([Clef::Core::Chord, Clef::Core::Rest])
  end

  it "records unsupported command warnings" do
    parser = described_class.new
    parser.parse("\\unknown { c'1 }")

    expect(parser.warnings).to include("unsupported LilyPond command ignored: \\unknown")
  end

  it "supports a small relative pitch subset" do
    score = described_class.new.parse("\\relative c' { c4 d e f }")
    pitches = score.staves.first.measures.first.voices[:default].elements.map(&:pitch)

    expect(pitches.map(&:to_lilypond)).to eq(["c'", "d'", "e'", "f'"])
  end

  it "imports a small new StaffGroup subset" do
    lilypond = <<~LY
      \\new StaffGroup <<
        \\new Staff { \\clef treble \\time 4/4 { c'4 d'4 e'4 f'4 } }
        \\new Staff { \\clef bass \\time 4/4 { c4 b,4 a,4 g,4 } }
      >>
    LY

    score = described_class.new.parse(lilypond)

    expect(score.staff_groups.last.bracket_type).to eq(:bracket)
    expect(score.staves.map { |staff| staff.clef.type }).to eq(%i[treble bass])
    expect(score.staves.map { |staff| staff.measures.first.voices[:default].elements.length }).to eq([4, 4])
  end

  it "imports simple simultaneous voices inside a staff" do
    lilypond = <<~LY
      \\new Staff {
        \\time 4/4
        << { c'4 d'4 e'4 f'4 } { g4 a4 b4 c'4 } >>
      }
    LY

    score = described_class.new.parse(lilypond)
    voices = score.staves.first.measures.first.voices

    expect(voices.keys).to eq(%i[default voice2])
    expect(voices.values.map { |voice| voice.elements.length }).to eq([4, 4])
  end

  it "warns and falls back for unsupported clefs" do
    parser = described_class.new
    score = parser.parse("\\clef unknown { c'1 }")

    expect(score.staves.first.clef.type).to eq(:treble)
    expect(parser.warnings).to include("unsupported clef ignored: unknown")
  end
end
