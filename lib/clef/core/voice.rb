# frozen_string_literal: true

module Clef
  module Core
    class Voice
      attr_reader :id, :elements

      # @param id [Symbol]
      def initialize(id: :default)
        @id = id
        @elements = []
      end

      # @param element [#length]
      # @return [Voice]
      def add(element)
        raise ArgumentError, "element must respond to #length" unless element.respond_to?(:length)

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
