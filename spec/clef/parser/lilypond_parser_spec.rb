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
end
