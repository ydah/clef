# frozen_string_literal: true

module Clef
  module Layout
    class SystemLayout
      System = Struct.new(:page_index, :line_index, :line_top, :start_moment, :end_moment,
        :position_offset, :staff_offsets, keyword_init: true) do
        def staff_offset(staff_id)
          staff_offsets.fetch(staff_id)
        end

        def include_moment?(moment)
          value = moment.is_a?(Clef::Ir::Moment) ? moment.value : Rational(moment)
          value.between?(start_moment.value, end_moment.value)
        end
      end

      attr_reader :score, :pages, :positions, :style

      # @param score [Clef::Core::Score]
      # @param pages [Array<Array<Array<Hash>>>]
      # @param positions [Hash]
      # @param style [Clef::Engraving::Style]
      def initialize(score, pages:, positions:, style:)
        @score = score
        @pages = pages
        @positions = positions
        @style = style
      end

      # @return [Array<System>]
      def build
        pages.flat_map.with_index do |page, page_index|
          page.map.with_index do |line, line_index|
            build_system(line, page_index, line_index)
          end
        end
      end

      private

      def build_system(line, page_index, line_index)
        start_moment = line.first.fetch(:moment)
        end_moment = line.last.fetch(:moment)
        System.new(
          page_index: page_index,
          line_index: line_index,
          line_top: line_index * system_height,
          start_moment: start_moment,
          end_moment: end_moment,
          position_offset: positions.fetch(start_moment, 0.0),
          staff_offsets: staff_offsets
        )
      end

      def staff_offsets
        score.staves.each_with_index.to_h { |staff, index| [staff.id, index * style.staff_gap] }
      end

      def system_height
        [(score.staves.length - 1), 0].max * style.staff_gap + style.system_gap
      end
    end
  end
end
