# frozen_string_literal: true

module Clef
  module Core
    class Voice
      ELEMENT_TYPES = [Note, Rest, Chord, Tuplet, Tempo].freeze

      attr_reader :id, :elements

      # @param id [Symbol]
      def initialize(id: :default)
        @id = id
        @elements = []
      end

      # @param element [Note, Rest, Chord, Tuplet]
      # @return [Voice]
      def add(element)
        raise ArgumentError, "element must be a musical element" unless musical_element?(element)

        elements << element
        self
      end

      # @return [Rational]
      def total_length
        elements.reduce(Rational(0, 1)) { |memo, element| memo + element.length }
      end

      private

      def musical_element?(element)
        return true if ELEMENT_TYPES.any? { |type| element.is_a?(type) }
        return true if defined?(::Clef::Notation::Dynamic) && element.is_a?(::Clef::Notation::Dynamic)

        false
      end
    end
  end
end
