# frozen_string_literal: true

module Clef
  module Ir
    class Moment
      include Comparable

      attr_reader :value

      # @param value [Rational, Integer]
      def initialize(value)
        @value = Rational(value)
      rescue TypeError
        raise ArgumentError, "moment value must be Rational-compatible"
      end

      # @param duration [Rational, #length]
      # @return [Moment]
      def +(other)
        self.class.new(value + normalize_duration(other))
      end

      # @param other [Moment, Rational, Integer]
      # @return [Rational]
      def -(other)
        value - normalize_other(other)
      end

      # @param other [Moment]
      # @return [Integer, nil]
      def <=>(other)
        return nil unless other.is_a?(self.class)

        value <=> other.value
      end

      def hash
        value.hash
      end

      def eql?(other)
        other.is_a?(self.class) && value.eql?(other.value)
      end

      private

      def normalize_duration(duration)
        return duration.length if duration.respond_to?(:length)

        Rational(duration)
      rescue TypeError
        raise ArgumentError, "duration must be Rational-compatible or respond to #length"
      end

      def normalize_other(other)
        return other.value if other.is_a?(self.class)

        Rational(other)
      rescue TypeError
        raise ArgumentError, "other must be a Moment or Rational-compatible"
      end
    end
  end
end
