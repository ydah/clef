# frozen_string_literal: true

module Clef
  module Engraving
    class GlyphTable
      GLYPHS = {
        notehead_black: "\uE0A4",
        notehead_half: "\uE0A3",
        notehead_whole: "\uE0A2",
        stem: "\uE210",
        flag_8th_up: "\uE240",
        flag_8th_down: "\uE241",
        flag_16th_up: "\uE242",
        flag_16th_down: "\uE243",
        rest_whole: "\uE4E3",
        rest_half: "\uE4E4",
        rest_quarter: "\uE4E5",
        rest_8th: "\uE4E6",
        rest_16th: "\uE4E7",
        clef_treble: "\uE050",
        clef_bass: "\uE062",
        clef_alto: "\uE05C",
        accidental_sharp: "\uE262",
        accidental_flat: "\uE260",
        accidental_double_sharp: "\uE263",
        accidental_double_flat: "\uE264",
        accidental_natural: "\uE261",
        dynamic_p: "\uE520",
        dynamic_f: "\uE522",
        fermata: "\uE4C0"
      }.merge((0..9).to_h { |n| [:"time_#{n}", (0xE080 + n).chr(Encoding::UTF_8)] }).freeze

      # @param glyphs [Hash]
      def initialize(glyphs: GLYPHS)
        @glyphs = glyphs.dup
      end

      # @param name [Symbol]
      # @return [String]
      def fetch(name)
        @glyphs.fetch(name)
      end

      # @param name [Symbol]
      # @return [String, nil]
      def [](name)
        @glyphs[name]
      end

      # @param name [Symbol]
      # @return [Boolean]
      def key?(name)
        @glyphs.key?(name)
      end

      # @param name [Symbol]
      # @param glyph [String]
      # @return [String]
      def register(name, glyph)
        raise ArgumentError, "glyph name must be a Symbol" unless name.is_a?(Symbol)
        raise ArgumentError, "glyph must be a String" unless glyph.is_a?(String)

        @glyphs[name] = glyph
      end
    end
  end
end
