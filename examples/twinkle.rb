# frozen_string_literal: true

require "clef"

score = Clef.score do
  title "Twinkle Twinkle Little Star"
  composer "Traditional"

  staff :melody, clef: :treble do
    key :c, :major
    time 4, 4
    play "c'4 c'4 g'4 g'4 | a'4 a'4 g'2 | f'4 f'4 e'4 e'4 | d'4 d'4 c'2"
  end
end

score.to_pdf("twinkle.pdf")
score.to_svg("twinkle.svg")
score.to_midi("twinkle.mid")
