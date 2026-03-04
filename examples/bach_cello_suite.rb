# frozen_string_literal: true

require "clef"

score = Clef.score do
  title "Cello Suite No.1 (Opening Motif)"
  composer "J. S. Bach"

  staff :cello, clef: :bass do
    key :g, :major
    time 4, 4
    play "g,8 d8 b8 d8 g8 d8 b8 d8 | g,8 e8 c8 e8 g8 e8 c8 e8"
  end
end

score.to_pdf("bach_cello_suite.pdf")
