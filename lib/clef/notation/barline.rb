# frozen_string_literal: true

module Clef
  module Notation
    class Barline
      TYPES = %i[single double final repeat_start repeat_end repeat_both].freeze

      attr_reader :type

      # @param type [Symbol]
      def initialize(type = :single)
        raise ArgumentError, "unsupported barline type" unless TYPES.include?(type)

        @type = type
      end

      # @return [String]
      def to_symbol
        {
          single: "|",
          double: "||",
          final: "|.",
          repeat_start: ".|:",
          repeat_end: ":|.",
          repeat_both: ":|.|:"
        }.fetch(type)
      end
    end
  end
end
