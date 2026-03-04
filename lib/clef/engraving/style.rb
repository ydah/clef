# frozen_string_literal: true

module Clef
  module Engraving
    class Style
      attr_reader :page_size, :margin, :staff_size, :staff_space, :min_note_spacing

      # @param page_size [String, Array]
      # @param margin [Numeric]
      # @param staff_size [Numeric]
      # @param staff_space [Numeric]
      # @param min_note_spacing [Numeric]
      def initialize(page_size: "A4", margin: 36, staff_size: 20, staff_space: 10, min_note_spacing: 24)
        @page_size = page_size
        @margin = margin
        @staff_size = staff_size
        @staff_space = staff_space
        @min_note_spacing = min_note_spacing
      end

      # @return [Style]
      def self.default
        new
      end
    end
  end
end
