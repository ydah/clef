# frozen_string_literal: true

module Clef
  module Core
    class Note
      attr_reader :pitch, :duration
      attr_accessor :articulations, :tied

      # @param pitch [Pitch]
      # @param duration [Duration]
      # @param articulations [Array<Symbol>]
      # @param tied [Boolean]
      def initialize(pitch, duration, articulations: [], tied: false)
        validate_pitch!(pitch)
        validate_duration!(duration)

        @pitch = pitch
        @duration = duration
        @articulations = Array(articulations).map(&:to_sym)
        @tied = !!tied
      end

      # @return [Rational]
      def length
        duration.length
      end

      private

      def validate_pitch!(pitch)
        return if pitch.is_a?(Pitch)

        raise ArgumentError, "pitch must be a Clef::Core::Pitch"
      end

      def validate_duration!(duration)
        return if duration.is_a?(Duration)

        raise ArgumentError, "duration must be a Clef::Core::Duration"
      end
    end
  end
end
