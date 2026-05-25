# frozen_string_literal: true

module Clef
  module Core
    class Chord
      attr_reader :pitches, :duration

      # @param pitches [Array<Pitch>]
      # @param duration [Duration]
      def initialize(pitches, duration)
        validate_pitches!(pitches)
        raise ArgumentError, "duration must be a Clef::Core::Duration" unless duration.is_a?(Duration)

        @pitches = Array(pitches)
        @duration = duration
      end

      # @return [Rational]
      def length
        duration.length
      end

      # @return [Array<Pitch>]
      def sorted_pitches
        pitches.sort
      end

      private

      def validate_pitches!(pitches)
        list = Array(pitches)
        raise ArgumentError, "pitches must not be empty" if list.empty?
        raise ArgumentError, "all chord pitches must be Clef::Core::Pitch" unless list.all? { |pitch| pitch.is_a?(Pitch) }
        return if list.map(&:semitones).uniq.length == list.length

        raise ArgumentError, "chord pitches must not contain duplicates"
      end
    end
  end
end
