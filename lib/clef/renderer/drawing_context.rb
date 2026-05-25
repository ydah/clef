# frozen_string_literal: true

module Clef
  module Renderer
    class DrawingContext
      attr_reader :vertical_axis

      # @param vertical_axis [Integer]
      def initialize(vertical_axis:)
        raise ArgumentError, "vertical_axis must be 1 or -1" unless [1, -1].include?(vertical_axis)

        @vertical_axis = vertical_axis
      end

      # @return [DrawingContext]
      def self.pdf
        new(vertical_axis: 1)
      end

      # @return [DrawingContext]
      def self.svg
        new(vertical_axis: -1)
      end
    end
  end
end
