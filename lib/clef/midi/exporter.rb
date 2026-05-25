# frozen_string_literal: true

require "midilib/sequence"
require "midilib/consts"

module Clef
  module Midi
    class Exporter
      include MIDI

      DEFAULT_VELOCITY = 90
      DEFAULT_PROGRAM = 1

      attr_reader :score, :channel_map, :ppqn, :instrument_map, :plugins

      # @param score [Clef::Core::Score]
      # @param channel_map [ChannelMap]
      # @param ppqn [Integer]
      # @param instrument_map [Hash]
      # @param plugins [Clef::Plugins::Registry]
      def initialize(score, channel_map: ChannelMap.new, ppqn: 480, instrument_map: {}, plugins: score.plugins || Clef.plugins)
        raise ArgumentError, "ppqn must be a positive Integer" unless ppqn.is_a?(Integer) && ppqn.positive?

        @score = score
        @channel_map = channel_map
        @ppqn = ppqn
        @instrument_map = instrument_map
        @plugins = plugins
      end

      # @param target [String, #write]
      # @return [String, #write]
      def export(target)
        plugins.run_hook(:on_before_midi, self)
        sequence = build_sequence
        write_sequence(sequence, target)
        target
      end

      private

      def build_sequence
        sequence = Sequence.new
        sequence.ppqn = ppqn
        append_tempo_track(sequence)
        append_staff_tracks(sequence)
        sequence
      end

      def append_tempo_track(sequence)
        track = Track.new(sequence)
        sequence.tracks << track
        last_tick = write_tempo_events(track)
        append_track_end(track, score_length, last_tick)
      end

      def append_staff_tracks(sequence)
        score.staves.each_with_index do |staff, index|
          track = Track.new(sequence)
          sequence.tracks << track
          channel = channel_for(staff, index)
          track.events << ProgramChange.new(channel, instrument_for(staff), 0)
          append_staff(track, staff, channel)
        end
      end

      def append_staff(track, staff, channel)
        note_events = collect_staff_note_events(staff, channel)
        last_tick = write_delta_events(track, note_events)
        append_track_end(track, staff_length(staff), last_tick)
      end

      def collect_staff_note_events(staff, channel)
        measure_start = Rational(0, 1)
        staff.measures.flat_map do |measure|
          events = measure.voices.values.flat_map do |voice|
            collect_voice_events(voice, measure_start, channel)
          end
          measure_start += measure_length_for(measure)
          events
        end
      end

      def collect_voice_events(voice, start_time, channel)
        events, = collect_elements(voice.elements, start_time, channel, Rational(1, 1), {}, {velocity: DEFAULT_VELOCITY},
          flush_ties: true)
        events
      end

      def collect_elements(elements, start_time, channel, ratio, pending_ties, playback_state, flush_ties:)
        cursor = start_time
        events = []
        elements.each do |element|
          case element
          when Clef::Core::Rest
            cursor += element.length * ratio
          when Clef::Core::Note
            events.concat(schedule_note(element, cursor, channel, ratio, pending_ties, playback_state))
            cursor += element.length * ratio
          when Clef::Core::Chord
            events.concat(schedule_chord(element, cursor, channel, ratio, playback_state))
            cursor += element.length * ratio
          when Clef::Core::Tuplet
            nested_events, = collect_elements(element.elements, cursor, channel, ratio * element.ratio,
              pending_ties, playback_state, flush_ties: false)
            events.concat(nested_events)
            cursor += element.length * ratio
          when Clef::Notation::Dynamic
            playback_state[:velocity] = velocity_for_dynamic(element)
          when Clef::Core::Tempo
            cursor += element.length
          end
        end
        events.concat(flush_pending_ties(pending_ties, channel)) if flush_ties
        [events, cursor]
      end

      def schedule_note(note, start_time, channel, ratio, pending_ties, playback_state)
        duration = note.length * ratio
        midi = note.pitch.to_midi
        if note.tie_state == :start || note.tie_state == :continue
          pending = pending_ties[midi] ||= {
            start_time: start_time,
            duration: Rational(0, 1),
            note: note,
            velocity: playback_state[:velocity]
          }
          pending[:duration] += duration
          return []
        end

        if note.tie_state == :stop && pending_ties.key?(midi)
          pending = pending_ties.delete(midi)
          pending[:duration] += duration
          return [note_event(pending[:note], pending[:start_time], pending[:duration], channel, pending[:velocity])]
        end

        [note_event(note, start_time, effective_note_length(note, duration), channel, playback_state[:velocity])]
      end

      def schedule_chord(chord, start_time, channel, ratio, playback_state)
        duration = chord.length * ratio
        chord.pitches.map do |pitch|
          {start_time: start_time, duration: duration, pitch: pitch.to_midi,
           velocity: playback_state[:velocity], channel: channel}
        end
      end

      def flush_pending_ties(pending_ties, channel)
        pending_ties.values.map do |pending|
          note_event(pending[:note], pending[:start_time], pending[:duration], channel, pending[:velocity])
        end.tap { pending_ties.clear }
      end

      def note_event(note, start_time, duration, channel, base_velocity)
        {
          start_time: start_time,
          duration: duration,
          pitch: note.pitch.to_midi,
          velocity: velocity_for(note, base_velocity),
          channel: channel
        }
      end

      def write_delta_events(track, note_events)
        absolute_events = note_events.flat_map do |event|
          start_tick = ticks_for(event[:start_time])
          end_tick = ticks_for(event[:start_time] + event[:duration])
          [
            [start_tick, 1, NoteOn.new(event[:channel], event[:pitch], event[:velocity], 0)],
            [end_tick, 0, NoteOff.new(event[:channel], event[:pitch], event[:velocity], 0)]
          ]
        end.sort_by { |tick, priority, _event| [tick, priority] }

        previous_tick = 0
        absolute_events.each do |tick, _priority, event|
          event.delta_time = tick - previous_tick
          track.events << event
          previous_tick = tick
        end
        previous_tick
      end

      def effective_note_length(note, duration)
        return duration * Rational(1, 2) if note.articulations.include?(:staccato)
        return duration * Rational(19, 20) if note.articulations.include?(:tenuto)

        duration
      end

      def velocity_for(note, base_velocity)
        return 112 if note.articulations.include?(:accent) || note.articulations.include?(:marcato)

        base_velocity
      end

      def velocity_for_dynamic(dynamic)
        {
          pp: 36,
          p: 48,
          mp: 64,
          mf: 80,
          f: 96,
          ff: 112,
          fff: 120,
          sfz: 120,
          fp: 96,
          cresc: 88,
          dim: 64
        }.fetch(dynamic.type)
      end

      def write_tempo_events(track)
        events = ([[Rational(0, 1), quarter_note_bpm]] + collect_score_tempo_events)
          .uniq { |time, _bpm| time }
          .sort_by(&:first)
        previous_tick = 0
        events.each do |time, bpm|
          tick = ticks_for(time)
          event = Tempo.new(Tempo.bpm_to_mpq(bpm))
          event.delta_time = tick - previous_tick
          track.events << event
          previous_tick = tick
        end
        previous_tick
      end

      def append_track_end(track, length, previous_tick)
        tick = ticks_for(length)
        track.events << MetaEvent.new(META_TRACK_END, nil, tick - previous_tick)
      end

      def collect_score_tempo_events
        score.staves.flat_map do |staff|
          measure_start = Rational(0, 1)
          staff.measures.flat_map do |measure|
            events = measure.voices.values.flat_map { |voice| collect_tempo_events(voice.elements, measure_start, Rational(1, 1)) }
            measure_start += measure_length_for(measure)
            events
          end
        end
      end

      def collect_tempo_events(elements, start_time, ratio)
        cursor = start_time
        elements.flat_map do |element|
          case element
          when Clef::Core::Rest, Clef::Core::Note, Clef::Core::Chord
            cursor += element.length * ratio
            []
          when Clef::Core::Tuplet
            nested = collect_tempo_events(element.elements, cursor, ratio * element.ratio)
            cursor += element.length * ratio
            nested
          when Clef::Core::Tempo
            [[cursor, tempo_to_quarter_bpm(element)]]
          else
            []
          end
        end
      end

      def ticks_for(time)
        (time * ppqn * 4).round
      end

      def measure_length_for(measure)
        return measure.time_signature.measure_length if measure.time_signature

        measure.voices.values.map(&:total_length).max || Rational(0, 1)
      end

      def staff_length(staff)
        staff.measures.sum { |measure| measure_length_for(measure) }
      end

      def score_length
        score.staves.map { |staff| staff_length(staff) }.max || Rational(0, 1)
      end

      def quarter_note_bpm
        tempo = score.tempo
        return 120 unless tempo

        tempo_to_quarter_bpm(tempo)
      end

      def tempo_to_quarter_bpm(tempo)
        (tempo.bpm * (tempo.beat_unit.length / Clef::Core::Duration.quarter.length)).round
      end

      def channel_for(staff, index)
        channel_map.channel_for(index, percussion: staff.clef.type == :percussion)
      end

      def instrument_for(staff)
        program = instrument_map.fetch(staff.id) do
          instrument_map.fetch(index_key(staff)) do
            staff.metadata.fetch(:midi_program) { staff.metadata.fetch(:program, DEFAULT_PROGRAM) }
          end
        end
        validate_program!(program)
        program
      end

      def index_key(staff)
        score.staves.index(staff)
      end

      def validate_program!(program)
        return if program.is_a?(Integer) && (0..127).cover?(program)

        raise ArgumentError, "MIDI program must be an Integer between 0 and 127"
      end

      def write_sequence(sequence, target)
        return sequence.write(target) if target.respond_to?(:write)

        ensure_parent_directory!(target)
        File.open(target, "wb") { |file| sequence.write(file) }
      end

      def ensure_parent_directory!(path)
        parent = File.dirname(path.to_s)
        return if parent.nil? || parent == "." || Dir.exist?(parent)

        raise ArgumentError, "output directory does not exist: #{parent}"
      end
    end
  end
end
