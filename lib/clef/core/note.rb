# frozen_string_literal: true

module Clef
  module Core
    class Note
      VALID_ARTICULATIONS = %i[staccato tenuto accent marcato fermata].freeze
      TIE_STATES = %i[start continue stop].freeze

      attr_reader :pitch, :duration
      attr_reader :tie_state
      attr_accessor :articulations, :slur_start, :slur_end, :beam_start, :beam_end

      # @param pitch [Pitch]
      # @param duration [Duration]
      # @param articulations [Array<Symbol>]
      # @param tied [Boolean, Symbol]
      def initialize(pitch, duration, articulations: [], tied: false)
        validate_pitch!(pitch)
        validate_duration!(duration)

        @pitch = pitch
        @duration = duration
        @articulations = normalize_articulations(articulations)
        @tie_state = normalize_tie_state(tied)
        @slur_start = false
        @slur_end = false
        @beam_start = false
        @beam_end = false
      end

      # @return [Rational]
      def length
        duration.length
      end

      # @return [Boolean]
      def tied
        !tie_state.nil?
      end

      # @param value [Boolean, Symbol]
      def tied=(value)
        @tie_state = normalize_tie_state(value)
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

      def normalize_articulations(values)
        symbols = Array(values).map(&:to_sym)
        invalid = symbols - VALID_ARTICULATIONS
        raise ArgumentError, "unsupported articulations: #{invalid.join(", ")}" unless invalid.empty?

        symbols
      end

      def normalize_tie_state(value)
        return nil if value.nil? || value == false
        return :start if value == true
        return value if TIE_STATES.include?(value)

        raise ArgumentError, "tied must be true, false, or one of #{TIE_STATES.inspect}"
      end
    end
  end
end
