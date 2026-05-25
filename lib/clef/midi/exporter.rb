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
        track.events << Tempo.new(Tempo.bpm_to_mpq(quarter_note_bpm))
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
        write_delta_events(track, note_events)
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
        events, = collect_elements(voice.elements, start_time, channel, Rational(1, 1), {})
        events
      end

      def collect_elements(elements, start_time, channel, ratio, pending_ties)
        cursor = start_time
        events = []
        elements.each do |element|
          case element
          when Clef::Core::Rest
            cursor += element.length * ratio
          when Clef::Core::Note
            events.concat(schedule_note(element, cursor, channel, ratio, pending_ties))
            cursor += element.length * ratio
          when Clef::Core::Chord
            events.concat(schedule_chord(element, cursor, channel, ratio))
            cursor += element.length * ratio
          when Clef::Core::Tuplet
            nested_events, = collect_elements(element.elements, cursor, channel, ratio * element.ratio, pending_ties)
            events.concat(nested_events)
            cursor += element.length * ratio
          end
        end
        events.concat(flush_pending_ties(pending_ties, channel))
        [events, cursor]
      end

      def schedule_note(note, start_time, channel, ratio, pending_ties)
        duration = note.length * ratio
        midi = note.pitch.to_midi
        if note.tie_state == :start || note.tie_state == :continue
          pending = pending_ties[midi] ||= { start_time: start_time, duration: Rational(0, 1), note: note }
          pending[:duration] += duration
          return []
        end

        if note.tie_state == :stop && pending_ties.key?(midi)
          pending = pending_ties.delete(midi)
          pending[:duration] += duration
          return [note_event(pending[:note], pending[:start_time], pending[:duration], channel)]
        end

        [note_event(note, start_time, effective_note_length(note, duration), channel)]
      end

      def schedule_chord(chord, start_time, channel, ratio)
        duration = chord.length * ratio
        chord.pitches.map do |pitch|
          { start_time: start_time, duration: duration, pitch: pitch.to_midi, velocity: DEFAULT_VELOCITY, channel: channel }
        end
      end

      def flush_pending_ties(pending_ties, channel)
        pending_ties.values.map do |pending|
          note_event(pending[:note], pending[:start_time], pending[:duration], channel)
        end.tap { pending_ties.clear }
      end

      def note_event(note, start_time, duration, channel)
        {
          start_time: start_time,
          duration: duration,
          pitch: note.pitch.to_midi,
          velocity: velocity_for(note),
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
      end

      def effective_note_length(note, duration)
        return duration * Rational(1, 2) if note.articulations.include?(:staccato)
        return duration * Rational(19, 20) if note.articulations.include?(:tenuto)

        duration
      end

      def velocity_for(note)
        return 112 if note.articulations.include?(:accent) || note.articulations.include?(:marcato)

        DEFAULT_VELOCITY
      end

      def ticks_for(time)
        (time * ppqn * 4).round
      end

      def measure_length_for(measure)
        return measure.time_signature.measure_length if measure.time_signature

        measure.voices.values.map(&:total_length).max || Rational(0, 1)
      end

      def quarter_note_bpm
        tempo = score.tempo
        return 120 unless tempo

        (tempo.bpm * (tempo.beat_unit.length / Clef::Core::Duration.quarter.length)).round
      end

      def channel_for(staff, index)
        channel_map.channel_for(index, percussion: staff.clef.type == :percussion)
      end

      def instrument_for(staff)
        instrument_map.fetch(staff.id) { instrument_map.fetch(index_key(staff), DEFAULT_PROGRAM) }
      end

      def index_key(staff)
        score.staves.index(staff)
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
