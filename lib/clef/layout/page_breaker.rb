# frozen_string_literal: true

module Clef
  module Layout
    class PageBreaker
      # @param lines [Array<Array<Hash>>]
      # @param page_height [Float]
      # @param line_height [Float]
      # @return [Array<Array<Array<Hash>>>]
      def break_into_pages(lines, page_height:, line_height:)
        max_lines = [(page_height / line_height).floor, 1].max
        lines.each_slice(max_lines).to_a
      end
    end
  end
end
