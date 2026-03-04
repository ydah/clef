# frozen_string_literal: true

module Clef
  module Notation
    class Articulation
      TYPES = %i[staccato tenuto accent marcato fermata].freeze

      attr_reader :type

      # @param type [Symbol]
      def initialize(type)
        raise ArgumentError, "unsupported articulation type" unless TYPES.include?(type)

        @type = type
      end
    end
  end
end
