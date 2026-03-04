# frozen_string_literal: true

module Clef
  module Core
    class KeySignature
      MAJOR_ACCIDENTALS = {
        c: { count: 0, type: :natural },
        g: { count: 1, type: :sharp },
        d: { count: 2, type: :sharp },
        a: { count: 3, type: :sharp },
        e: { count: 4, type: :sharp },
        b: { count: 5, type: :sharp },
        fis: { count: 6, type: :sharp },
        cis: { count: 7, type: :sharp },
        f: { count: 1, type: :flat },
        bes: { count: 2, type: :flat },
        ees: { count: 3, type: :flat },
        aes: { count: 4, type: :flat },
        des: { count: 5, type: :flat },
        ges: { count: 6, type: :flat },
        ces: { count: 7, type: :flat }
      }.freeze
      MINOR_ACCIDENTALS = {
        a: { count: 0, type: :natural },
        e: { count: 1, type: :sharp },
        b: { count: 2, type: :sharp },
        fis: { count: 3, type: :sharp },
        cis: { count: 4, type: :sharp },
        gis: { count: 5, type: :sharp },
        dis: { count: 6, type: :sharp },
        ais: { count: 7, type: :sharp },
        d: { count: 1, type: :flat },
        g: { count: 2, type: :flat },
        c: { count: 3, type: :flat },
        f: { count: 4, type: :flat },
        bes: { count: 5, type: :flat },
        ees: { count: 6, type: :flat },
        aes: { count: 7, type: :flat }
      }.freeze

      attr_reader :tonic, :mode

      # @param tonic [Pitch, Symbol]
      # @param mode [Symbol]
      def initialize(tonic, mode = :major)
        @tonic = normalize_tonic(tonic)
        validate_mode!(mode)
        @mode = mode
      end

      # @return [Hash]
      def accidentals
        table = mode == :major ? MAJOR_ACCIDENTALS : MINOR_ACCIDENTALS
        table.fetch(tonic_key) { { count: 0, type: :natural } }
      end

      private

      def normalize_tonic(tonic)
        return tonic if tonic.is_a?(Pitch)
        return Pitch.new(tonic, 4) if tonic.is_a?(Symbol)

        raise ArgumentError, "tonic must be a Pitch or Symbol"
      end

      def tonic_key
        base = tonic.note_name.to_s
        suffix = tonic.alteration.positive? ? "is" * tonic.alteration : "es" * tonic.alteration.abs
        "#{base}#{suffix}".to_sym
      end

      def validate_mode!(mode)
        return if %i[major minor].include?(mode)

        raise ArgumentError, "mode must be :major or :minor"
      end
    end
  end
end
