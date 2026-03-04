# frozen_string_literal: true

module Clef
  module Core
    class TimeSignature
      attr_reader :numerator, :denominator

      # @param numerator [Integer]
      # @param denominator [Integer]
      def initialize(numerator, denominator)
        validate_numerator!(numerator)
        validate_denominator!(denominator)

        @numerator = numerator
        @denominator = denominator
      end

      # @return [Rational]
      def measure_length
        Rational(numerator, denominator)
      end

      private

      def validate_numerator!(value)
        return if value.is_a?(Integer) && value.positive?

        raise ArgumentError, "numerator must be a positive Integer"
      end

      def validate_denominator!(value)
        return if value.is_a?(Integer) && value.positive? && (value & (value - 1)).zero?

        raise ArgumentError, "denominator must be a positive power of two"
      end
    end
  end
end
