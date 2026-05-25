# frozen_string_literal: true

module Clef
  module Layout
    class Spacing
      attr_reader :timeline, :style, :stretch_factor, :extra_moments

      # @param timeline [Clef::Ir::Timeline]
      # @param style [Clef::Engraving::Style]
      # @param extra_moments [Array<Clef::Ir::Moment>]
      def initialize(timeline, style, extra_moments: [])
        @timeline = timeline
        @style = style
        @extra_moments = extra_moments
        @stretch_factor = 1.0
      end

      # @return [Hash{Clef::Ir::Moment=>Float}]
      def compute
        moments = (timeline.each_moment.to_a + extra_moments).uniq.sort
        return {} if moments.empty?

        build_positions(moments)
      end

      # @param target_width [Numeric]
      # @return [Float]
      def stretch_to_fit(target_width)
        positions = compute
        return stretch_factor if positions.empty?

        current_width = positions.values.max
        return stretch_factor unless current_width.positive?

        @stretch_factor *= target_width.to_f / current_width
      end

      private

      def build_positions(moments)
        positions = { moments.first => 0.0 }
        total = 0.0
        moments.each_cons(2) do |left, right|
          total += interval_width(right.value - left.value)
          positions[right] = total
        end
        positions
      end

      def interval_width(duration)
        shortest = timeline.shortest_duration
        ratio = duration.to_f / shortest.to_f
        base = style.min_note_spacing
        base * Math.log2(ratio + 1.0) * stretch_factor
      end
    end
  end
end
