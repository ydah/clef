# frozen_string_literal: true

module Clef
  module Core
    class Tempo
      attr_reader :beat_unit, :bpm

      # @param beat_unit [Duration]
      # @param bpm [Integer]
      def initialize(beat_unit:, bpm:)
        raise ArgumentError, "beat_unit must be a Clef::Core::Duration" unless beat_unit.is_a?(Duration)
        raise ArgumentError, "bpm must be a positive Integer" unless bpm.is_a?(Integer) && bpm.positive?

        @beat_unit = beat_unit
        @bpm = bpm
      end

      # @return [Rational]
      def length
        Rational(0, 1)
      end
    end
  end
end
