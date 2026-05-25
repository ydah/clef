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

  it "parses chord shorthand with spaces" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        play "<c' e' g'>2 r2"
      end
    end

    elements = score.staves.first.measures.first.voices[:default].elements
    expect(elements.first).to be_a(Clef::Core::Chord)
    expect(elements.first.pitches.map(&:to_lilypond)).to eq(["c'", "e'", "g'"])
  end

  it "inherits the previous duration in play shorthand" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        play "c'4 d' e' f'"
      end
    end

    durations = score.staves.first.measures.first.voices[:default].elements.map(&:duration)
    expect(durations.map(&:to_lilypond)).to eq(%w[4 4 4 4])
  end

  it "parses ties, articulations, slurs, and beam hints lightly" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        play "( c'4~ c'4 ) d'4 -. [ e'4 ]"
      end
    end

    notes = score.staves.first.measures.first.voices[:default].elements
    expect(notes[0].tie_state).to eq(:start)
    expect(notes[0].slur_start).to be(true)
    expect(notes[1].tie_state).to eq(:stop)
    expect(notes[1].slur_end).to be(true)
    expect(notes[2].articulations).to eq([:staccato])
    expect(notes[3].beam_start).to be(true)
    expect(notes[3].beam_end).to be(true)
  end

  it "adds dynamics and voice-level tempo changes as zero-length events" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        voice do
          dynamic :mf
          note "C4", :quarter
          tempo beat_unit: :quarter, bpm: 90
          note "D4", :quarter
        end
      end
    end

    voice = score.staves.first.measures.first.voices[:default]

    expect(voice.elements.map(&:class)).to eq([
      Clef::Notation::Dynamic,
      Clef::Core::Note,
      Clef::Core::Tempo,
      Clef::Core::Note
    ])
    expect(voice.total_length).to eq(Rational(1, 2))
  end

  it "parses dynamic commands in play shorthand" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        play "\\mf c'4 \\p d'4"
      end
    end

    elements = score.staves.first.measures.first.voices[:default].elements

    expect(elements.map(&:class)).to eq([
      Clef::Notation::Dynamic,
      Clef::Core::Note,
      Clef::Notation::Dynamic,
      Clef::Core::Note
    ])
    expect(elements.values_at(0, 2).map(&:type)).to eq(%i[mf p])
  end

  it "builds tuplets with scaled total length" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        voice do
          tuplet 3, 2 do
            notes "c'8 d'8 e'8"
          end
          rest :half
        end
      end
    end

    tuplet = score.staves.first.measures.first.voices[:default].elements.first
    expect(tuplet.length).to eq(Rational(1, 4))
  end

  it "supports block argument style" do
    score = Clef.score do |s|
      s.staff :melody do |staff|
        staff.time 4, 4
        staff.play "c'1"
      end
    end

    expect(score.staves.first.measures.first.voices[:default].elements.length).to eq(1)
  end

  it "supports explicit measure and bar helpers" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        measure do
          voice { notes "c'1" }
        end
        measure do
          voice { notes "d'1" }
        end
      end
    end

    expect(score.staves.first.measures.length).to eq(2)
  end

  it "requires staff_group blocks" do
    expect do
      Clef.score do
        staff_group :brace
      end
    end.to raise_error(Clef::Parser::DSL::Error, /requires a block/)
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
