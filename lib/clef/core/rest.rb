# frozen_string_literal: true

module Clef
  module Core
    class Rest
      KINDS = %i[visible invisible spacer multi_measure].freeze

      attr_reader :duration, :kind, :measures

      # @param duration [Duration]
      # @param kind [Symbol]
      # @param measures [Integer]
      def initialize(duration, kind: :visible, measures: 1)
        raise ArgumentError, "duration must be a Clef::Core::Duration" unless duration.is_a?(Duration)
        raise ArgumentError, "unsupported rest kind" unless KINDS.include?(kind)
        raise ArgumentError, "measures must be positive" unless measures.is_a?(Integer) && measures.positive?

        @duration = duration
        @kind = kind
        @measures = measures
      end

      # @return [Rational]
      def length
        duration.length * measures
      end
    end
  end
end
