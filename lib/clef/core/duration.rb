# frozen_string_literal: true

module Clef
  module Core
    class Duration
      include Comparable

      BASE_VALUES = {
        whole: Rational(1, 1),
        half: Rational(1, 2),
        quarter: Rational(1, 4),
        eighth: Rational(1, 8),
        sixteenth: Rational(1, 16),
        thirty_second: Rational(1, 32),
        sixty_fourth: Rational(1, 64),
        one_twenty_eighth: Rational(1, 128),
        two_fifty_sixth: Rational(1, 256)
      }.freeze
      NUMBER_TO_BASE = {
        1 => :whole,
        2 => :half,
        4 => :quarter,
        8 => :eighth,
        16 => :sixteenth,
        32 => :thirty_second,
        64 => :sixty_fourth,
        128 => :one_twenty_eighth,
        256 => :two_fifty_sixth
      }.freeze
      BASE_TO_NUMBER = NUMBER_TO_BASE.invert.freeze

      attr_reader :base, :dots

      # @param base [Symbol]
      # @param dots [Integer]
      def initialize(base, dots: 0)
        validate_base!(base)
        validate_dots!(dots)

        @base = base
        @dots = dots
        freeze
      end

      # @return [Rational]
      def base_value
        BASE_VALUES.fetch(base)
      end

      # @return [Rational]
      def length
        base_value * (Rational(2, 1) - Rational(1, 2**dots))
      end

      # @param other [Duration]
      # @return [Integer, nil]
      def <=>(other)
        return nil unless other.is_a?(self.class)

        length <=> other.length
      end

      # @return [String]
      def to_lilypond
        "#{BASE_TO_NUMBER.fetch(base)}#{"." * dots}"
      end

      # @param number [Integer]
      # @param dots [Integer]
      # @return [Duration]
      def self.from_lilypond(number, dots = 0)
        new(NUMBER_TO_BASE.fetch(number), dots: dots)
      rescue KeyError
        raise ArgumentError, "unsupported lilypond duration: #{number}"
      end

      class << self
        BASE_VALUES.keys.each do |duration_name|
          define_method(duration_name) do
            new(duration_name)
          end
        end
      end

      private

      def validate_base!(base)
        return if BASE_VALUES.key?(base)

        raise ArgumentError, "unknown duration base: #{base.inspect}"
      end

      def validate_dots!(dots)
        return if dots.is_a?(Integer) && (0..3).cover?(dots)

        raise ArgumentError, "dots must be an Integer between 0 and 3"
      end
    end
  end
end
