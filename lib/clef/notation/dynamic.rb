# frozen_string_literal: true

module Clef
  module Notation
    class Dynamic
      TYPES = %i[pp p mp mf f ff fff sfz fp cresc dim].freeze

      attr_reader :type

      # @param type [Symbol]
      def initialize(type)
        raise ArgumentError, "unsupported dynamic type" unless TYPES.include?(type)

        @type = type
      end

      # @return [Rational]
      def length
        Rational(0, 1)
      end
    end
  end
end
