# frozen_string_literal: true

require "tmpdir"
require "stringio"

RSpec.describe Clef::Midi::Exporter do
  it "exports score to midi file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.mid")
      described_class.new(simple_score).export(path)

      expect(File.exist?(path)).to be(true)
      expect(File.size(path)).to be > 0
    end
  end

  it "exports all voices on staff tracks" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        voice(:upper) do
          note "C4", :quarter
          note "D4", :quarter
        end
        voice(:lower) do
          note "E4", :quarter
          note "F4", :quarter
        end
      end
    end

    sequence = export_sequence(score)
    note_ons = sequence.tracks[1].events.select { |event| event.is_a?(MIDI::NoteOn) }

    expect(sequence.tracks.length).to eq(2)
    expect(note_ons.map(&:note)).to contain_exactly(60, 62, 64, 65)
    expect(note_ons.first.delta_time).to eq(0)
    expect(note_ons[1].delta_time).to eq(0)
  end

  it "applies tempo beat unit, ppqn, and instrument options" do
    score = Clef.score do
      tempo beat_unit: :half, bpm: 60
      staff :melody do
        time 4, 4
        voice { note "C4", :quarter }
      end
    end

    sequence = export_sequence(score, ppqn: 960, instrument_map: {melody: 40})
    tempo = sequence.tracks[0].events.find { |event| event.is_a?(MIDI::Tempo) }
    program = sequence.tracks[1].events.find { |event| event.is_a?(MIDI::ProgramChange) }

    expect(sequence.ppqn).to eq(960)
    expect(tempo.tempo).to eq(MIDI::Tempo.bpm_to_mpq(120))
    expect(program.program).to eq(40)
  end

  it "uses staff metadata MIDI programs when no exporter override is provided" do
    score = Clef.score do
      staff :melody do
        instrument 41
        voice { note "C4", :quarter }
      end
    end

    program = export_sequence(score).tracks[1].events.find { |event| event.is_a?(MIDI::ProgramChange) }

    expect(program.program).to eq(41)
  end

  it "routes percussion clef staves to MIDI channel 10" do
    score = Clef.score do
      staff :drums, clef: :percussion do
        voice { note "C4", :quarter }
      end
    end

    events = export_sequence(score).tracks[1].events
    program = events.find { |event| event.is_a?(MIDI::ProgramChange) }
    note_on = events.find { |event| event.is_a?(MIDI::NoteOn) }

    expect(program.channel).to eq(9)
    expect(note_on.channel).to eq(9)
  end

  it "keeps rests and tied notes in absolute-time scheduling" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        voice do
          rest :quarter
          note "C4", :quarter, tied: :start
          note "C4", :quarter, tied: :stop
          note "D4", :quarter, articulations: [:staccato]
        end
      end
    end

    sequence = export_sequence(score)
    events = sequence.tracks[1].events
    note_ons = events.select { |event| event.is_a?(MIDI::NoteOn) }
    note_offs = events.select { |event| event.is_a?(MIDI::NoteOff) }

    expect(note_ons.map(&:note)).to eq([60, 62])
    expect(note_ons.first.delta_time).to eq(480)
    expect(note_offs.first.delta_time).to eq(960)
    expect(note_offs.last.delta_time).to eq(240)
  end

  it "keeps ties pending across tuplet boundaries" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        voice do
          tuplet 3, 2 do
            rest :eighth
            rest :eighth
            note "C4", :eighth, tied: :start
          end
          note "C4", :quarter, tied: :stop
        end
      end
    end

    events = export_sequence(score).tracks[1].events
    note_ons = events.select { |event| event.is_a?(MIDI::NoteOn) }
    note_offs = events.select { |event| event.is_a?(MIDI::NoteOff) }

    expect(note_ons.map(&:note)).to eq([60])
    expect(note_ons.first.delta_time).to eq(320)
    expect(note_offs.first.delta_time).to eq(640)
  end

  it "keeps ties pending across measure boundaries" do
    score = Clef.score do
      staff :melody do
        time 2, 4
        play "c'2~ | c'2"
      end
    end

    events = export_sequence(score).tracks[1].events
    note_ons = events.select { |event| event.is_a?(MIDI::NoteOn) }
    note_offs = events.select { |event| event.is_a?(MIDI::NoteOff) }

    expect(note_ons.map(&:note)).to eq([60])
    expect(note_ons.first.delta_time).to eq(0)
    expect(note_offs.first.delta_time).to eq(1920)
  end

  it "keeps dotted note durations in MIDI scheduling" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        voice do
          note "C4", :quarter, dots: 1
          rest :eighth
        end
      end
    end

    note_off = export_sequence(score).tracks[1].events.find { |event| event.is_a?(MIDI::NoteOff) }

    expect(note_off.delta_time).to eq(720)
  end

  it "extends non-final slurred notes for legato playback" do
    score = Clef.score do
      staff :melody do
        time 2, 4
        play "( c'4 d'4 )"
      end
    end

    messages = export_sequence(score).tracks[1].events.select do |event|
      event.is_a?(MIDI::NoteOn) || event.is_a?(MIDI::NoteOff)
    end

    expect(messages.map { |event| [event.class, event.note, event.delta_time] }).to eq([
      [MIDI::NoteOn, 60, 0],
      [MIDI::NoteOn, 62, 480],
      [MIDI::NoteOff, 60, 5],
      [MIDI::NoteOff, 62, 475]
    ])
  end

  it "exports dynamics as note velocity and voice tempo changes on the tempo track" do
    score = Clef.score do
      tempo beat_unit: :quarter, bpm: 120
      staff :melody do
        time 4, 4
        voice do
          dynamic :p
          note "C4", :quarter
          tempo beat_unit: :quarter, bpm: 90
          dynamic :f
          note "D4", :quarter
        end
      end
    end

    sequence = export_sequence(score)
    tempos = sequence.tracks[0].events.select { |event| event.is_a?(MIDI::Tempo) }
    note_ons = sequence.tracks[1].events.select { |event| event.is_a?(MIDI::NoteOn) }

    expect(tempos.map(&:tempo)).to eq([
      MIDI::Tempo.bpm_to_mpq(120),
      MIDI::Tempo.bpm_to_mpq(90)
    ])
    expect(tempos.map(&:delta_time)).to eq([0, 480])
    expect(note_ons.map(&:velocity)).to eq([48, 96])
  end

  it "preserves rest-only and empty measure duration with track end deltas" do
    rest_score = Clef.score do
      staff :melody do
        time 4, 4
        voice { rest :whole }
      end
    end
    empty_score = Clef.score do
      staff :melody do
        time 4, 4
        measure {}
      end
    end

    rest_track_end = export_sequence(rest_score).tracks[1].events.last
    empty_track_end = export_sequence(empty_score).tracks[1].events.last

    expect(rest_track_end.meta_type).to eq(MIDI::META_TRACK_END)
    expect(empty_track_end.meta_type).to eq(MIDI::META_TRACK_END)
    expect(rest_track_end.delta_time).to eq(1920)
    expect(empty_track_end.delta_time).to eq(1920)
  end

  it "preserves multi-measure rest duration without note events" do
    score = Clef.score do
      staff :melody do
        voice { rest :whole, kind: :multi_measure, measures: 3 }
      end
    end

    track = export_sequence(score).tracks[1]

    expect(track.events.none? { |event| event.is_a?(MIDI::NoteOn) }).to be(true)
    expect(track.events.last.delta_time).to eq(5760)
  end

  it "writes to IO objects and validates missing output directories" do
    io = StringIO.new
    described_class.new(simple_score).export(io)

    expect(io.string.bytesize).to be > 0
    expect do
      described_class.new(simple_score).export("/missing-clef-dir/score.mid")
    end.to raise_error(ArgumentError, /output directory/)
  end

  def export_sequence(score, **options)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.mid")
      described_class.new(score, **options).export(path)
      sequence = MIDI::Sequence.new
      File.open(path, "rb") { |file| sequence.read(file) }
      return sequence
    end
  end
end
