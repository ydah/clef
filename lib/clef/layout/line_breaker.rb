# frozen_string_literal: true

module Clef
  module Layout
    class LineBreaker
      # @param columns [Array<Hash>]
      # @param line_width [Float]
      # @return [Array<Array<Hash>>]
      def break_into_lines(columns, line_width)
        costs, breaks = initialize_dp(columns.length)
        1.upto(columns.length) { |idx| update_dp_for_index(columns, line_width, idx, costs, breaks) }
        build_lines(columns, breaks)
      end

      private

      def initialize_dp(size)
        costs = Array.new(size + 1, Float::INFINITY)
        breaks = Array.new(size + 1)
        costs[0] = 0.0
        [costs, breaks]
      end

      def update_dp_for_index(columns, line_width, idx, costs, breaks)
        width = 0.0
        idx.downto(1) do |start_idx|
          width += column_width(columns[start_idx - 1])
          break if width > line_width && start_idx != idx

          relax_edge(columns, idx, start_idx, width, line_width, costs, breaks)
        end
      end

      def relax_edge(columns, idx, start_idx, width, line_width, costs, breaks)
        badness = (line_width - width).abs**2
        penalty = (columns[idx - 1][:break_penalty] || 0).to_f
        next_cost = costs[start_idx - 1] + badness + penalty
        return unless next_cost < costs[idx]

        costs[idx] = next_cost
        breaks[idx] = start_idx - 1
      end

      def build_lines(columns, breaks)
        slices = []
        index = columns.length
        while index.positive?
          start_index = breaks[index] || 0
          slices.unshift(columns[start_index...index])
          index = start_index
        end
        slices
      end

      def column_width(column)
        column.fetch(:width).to_f
      end
    end
  end
end
