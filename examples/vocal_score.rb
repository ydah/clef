# frozen_string_literal: true

require "clef"

score = Clef.score do
  title "Vocal Example"
  composer "Clef Demo"

  staff :voice, clef: :treble do
    key :f, :major
    time 3, 4

    voice :singer do
      notes "a'4 bes'4 c''4"
    end

    lyrics :singer, "la-la la"
  end
end

score.to_pdf("vocal_score.pdf")
