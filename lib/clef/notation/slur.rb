# frozen_string_literal: true

module Clef
  module Notation
    class Slur
      attr_reader :start_note, :end_note

      # @param start_note [Clef::Core::Note]
      # @param end_note [Clef::Core::Note]
      def initialize(start_note, end_note)
        @start_note = start_note
        @end_note = end_note
      end

      # @param start_point [Array<Float>]
      # @param end_point [Array<Float>]
      # @return [Array<Array<Float>>]
      def control_points(start_point, end_point)
        midpoint_x = (start_point[0] + end_point[0]) / 2.0
        lift = [((end_point[0] - start_point[0]).abs / 4.0), 6.0].max
        [
          [midpoint_x - 8, start_point[1] - lift],
          [midpoint_x + 8, end_point[1] - lift]
        ]
      end
    end
  end
end
