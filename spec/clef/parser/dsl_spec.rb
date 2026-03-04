# frozen_string_literal: true

RSpec.describe Clef::Parser::DSL do
  it "builds score from DSL" do
    score = Clef.score do
      title "Twinkle"
      composer "Mozart"
      tempo beat_unit: :quarter, bpm: 100

      staff :melody, clef: :treble do
        key :c, :major
        time 4, 4

        voice do
          notes "c'4 c'4 g'4 g'4"
        end
      end
    end

    staff = score.staves.first
    voice = staff.measures.first.voices[:default]

    expect(score.title).to eq("Twinkle")
    expect(voice.elements.length).to eq(4)
  end

  it "parses play shorthand" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        play "c'4 d'8 e'8 r4"
      end
    end

    elements = score.staves.first.measures.first.voices[:default].elements
    expect(elements.map(&:class)).to eq([Clef::Core::Note, Clef::Core::Note, Clef::Core::Note, Clef::Core::Rest])
  end

  it "raises clear error for invalid DSL" do
    expect do
      Clef.score do
        staff :melody do
          unknown_method 1
        end
      end
    end.to raise_error(Clef::Parser::DSL::Error, /invalid DSL method/)
  end
end
