# frozen_string_literal: true

module Clef
  module Core
    class Tuplet
      ELEMENT_TYPES = [Note, Rest, Chord, self].freeze

      attr_reader :actual, :normal, :elements

      # @param actual [Integer]
      # @param normal [Integer]
      # @param elements [Array<Note, Rest, Chord, Tuplet>]
      def initialize(actual, normal, elements)
        raise ArgumentError, "tuplet values must be positive" unless actual.is_a?(Integer) && actual.positive? &&
          normal.is_a?(Integer) && normal.positive?

        @actual = actual
        @normal = normal
        @elements = Array(elements)
        validate_elements!
      end

      # @return [Rational]
      def length
        raw_length * ratio
      end

      # @return [Rational]
      def ratio
        Rational(normal, actual)
      end

      private

      def raw_length
        elements.reduce(Rational(0, 1)) { |memo, element| memo + element.length }
      end

      def validate_elements!
        raise ArgumentError, "tuplet must contain at least one element" if elements.empty?
        return if elements.all? { |element| ELEMENT_TYPES.any? { |type| element.is_a?(type) } }

        raise ArgumentError, "tuplet elements must be musical elements"
      end
    end
  end
end
