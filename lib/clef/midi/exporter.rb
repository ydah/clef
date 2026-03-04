# frozen_string_literal: true

require "midilib/sequence"
require "midilib/consts"

module Clef
  module Midi
    class Exporter
      include MIDI

      # @param score [Clef::Core::Score]
      # @param channel_map [ChannelMap]
      def initialize(score, channel_map: ChannelMap.new)
        @score = score
        @channel_map = channel_map
      end

      # @param path [String]
      # @return [String]
      def export(path)
        sequence = Sequence.new
        track = Track.new(sequence)
        sequence.tracks << track
        track.events << Tempo.new(Tempo.bpm_to_mpq(tempo_bpm))

        append_score(track, sequence.ppqn)
        File.open(path, "wb") { |file| sequence.write(file) }
        path
      end

      private

      def append_score(track, ppqn)
        @score.staves.each_with_index do |staff, index|
          channel = @channel_map.channel_for(index)
          track.events << ProgramChange.new(channel, 1, 0)
          append_staff(track, staff, channel, ppqn)
        end
      end

      def append_staff(track, staff, channel, ppqn)
        delta = 0
        staff.measures.each do |measure|
          voice = measure.voices.values.first
          delta = append_voice(track, voice, channel, ppqn, delta) if voice
        end
      end

      def append_voice(track, voice, channel, ppqn, delta)
        voice.elements.each do |element|
          delta = append_element(track, element, channel, ppqn, delta)
        end
        delta
      end

      def append_element(track, element, channel, ppqn, delta)
        ticks = (element.length * ppqn * 4).to_i
        return delta + ticks if element.is_a?(Clef::Core::Rest)

        pitches = element.is_a?(Clef::Core::Chord) ? element.pitches : [element.pitch]
        write_note_events(track, channel, pitches, ticks, delta)
        0
      end

      def write_note_events(track, channel, pitches, ticks, delta)
        pitches.each_with_index do |pitch, index|
          note_delta = index.zero? ? delta : 0
          track.events << NoteOn.new(channel, pitch.to_midi, 90, note_delta)
        end
        pitches.each_with_index do |pitch, index|
          note_delta = index.zero? ? ticks : 0
          track.events << NoteOff.new(channel, pitch.to_midi, 90, note_delta)
        end
      end

      def tempo_bpm
        @score.tempo&.bpm || 120
      end
    end
  end
end
