# frozen_string_literal: true

module Clef
  module Core
    class Voice
      ELEMENT_TYPES = [Note, Rest, Chord, Tuplet].freeze

      attr_reader :id, :elements

      # @param id [Symbol]
      def initialize(id: :default)
        @id = id
        @elements = []
      end

      # @param element [Note, Rest, Chord, Tuplet]
      # @return [Voice]
      def add(element)
        raise ArgumentError, "element must be a musical element" unless ELEMENT_TYPES.any? { |type| element.is_a?(type) }

        elements << element
        self
      end

      # @return [Rational]
      def total_length
        elements.reduce(Rational(0, 1)) { |memo, element| memo + element.length }
      end
    end
  end
end
