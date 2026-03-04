# frozen_string_literal: true

module ScoreFactory
  def simple_score
    Clef.score do
      staff :melody, clef: :treble do
        time 4, 4
        voice do
          notes "c'4 d'4 e'4 f'4"
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include ScoreFactory
end
