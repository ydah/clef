# frozen_string_literal: true

require "clef"

score = Clef.score do
  title "Piano Example"
  composer "Clef Demo"

  staff_group :brace do
    staff :piano_rh, name: "Piano RH", clef: :treble do
      key :c, :major
      time 4, 4
      play "c'4 e'4 g'4 c''4"
    end

    staff :piano_lh, name: "Piano LH", clef: :bass do
      key :c, :major
      time 4, 4
      play "c2 g,2"
    end
  end
end

score.to_pdf("piano_score.pdf")
