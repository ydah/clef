# frozen_string_literal: true

module Clef
  module Engraving
    class Style
      attr_reader :page_size, :margin, :staff_size, :staff_space, :min_note_spacing,
        :line_width, :system_gap, :staff_gap, :measure_padding,
        :notehead_width, :beam_thickness

      # @param page_size [String, Array]
      # @param margin [Numeric]
      # @param staff_size [Numeric]
      # @param staff_space [Numeric]
      # @param min_note_spacing [Numeric]
      # @param line_width [Numeric]
      # @param system_gap [Numeric]
      # @param staff_gap [Numeric]
      # @param measure_padding [Numeric]
      # @param notehead_width [Numeric]
      # @param beam_thickness [Numeric]
      def initialize(page_size: "A4", margin: 36, staff_size: 20, staff_space: 10, min_note_spacing: nil,
        line_width: 820, system_gap: 72, staff_gap: 90, measure_padding: 14,
        notehead_width: 7, beam_thickness: nil)
        min_note_spacing ||= Rules::MIN_NOTE_SPACING * staff_space
        beam_thickness ||= Rules::BEAM_THICKNESS * staff_space

        validate_positive!(
          margin: margin,
          staff_size: staff_size,
          staff_space: staff_space,
          min_note_spacing: min_note_spacing,
          line_width: line_width,
          system_gap: system_gap,
          staff_gap: staff_gap,
          measure_padding: measure_padding,
          notehead_width: notehead_width,
          beam_thickness: beam_thickness
        )

        @page_size = page_size
        @margin = margin
        @staff_size = staff_size
        @staff_space = staff_space
        @min_note_spacing = min_note_spacing
        @line_width = line_width
        @system_gap = system_gap
        @staff_gap = staff_gap
        @measure_padding = measure_padding
        @notehead_width = notehead_width
        @beam_thickness = beam_thickness
      end

      # @return [Style]
      def self.default
        new
      end

      private

      def validate_positive!(values)
        invalid = values.filter_map { |name, value| name unless value.is_a?(Numeric) && value.positive? }
        raise ArgumentError, "style values must be positive: #{invalid.join(", ")}" unless invalid.empty?
      end
    end
  end
end
