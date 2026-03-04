# frozen_string_literal: true

module Clef
  module Core
    class Clef
      TYPES = %i[treble bass alto tenor soprano mezzo_soprano baritone percussion tab].freeze
      REFERENCE = {
        treble: [[:b, 4], 2],
        bass: [[:d, 3], 2],
        alto: [[:c, 4], 2],
        tenor: [[:a, 3], 2],
        soprano: [[:g, 4], 2],
        mezzo_soprano: [[:e, 4], 2],
        baritone: [[:f, 3], 2],
        percussion: [[:b, 4], 2],
        tab: [[:b, 4], 2]
      }.freeze

      attr_reader :type

      # @param type [Symbol]
      def initialize(type)
        raise ArgumentError, "unsupported clef type: #{type}" unless TYPES.include?(type)

        @type = type
      end

      # @return [Pitch]
      def reference_pitch
        note_name, octave = REFERENCE.fetch(type).first
        Pitch.new(note_name, octave)
      end

      # @return [Integer]
      def reference_line
        REFERENCE.fetch(type).last
      end
    end
  end
end
