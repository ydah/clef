# frozen_string_literal: true

module Clef
  module Renderer
    class Base
      attr_reader :style, :glyph_table, :font_manager

      # @param style [Clef::Engraving::Style]
      # @param glyph_table [Clef::Engraving::GlyphTable]
      # @param font_manager [Clef::Engraving::FontManager]
      def initialize(style: Clef::Engraving::Style.default,
                     glyph_table: Clef::Engraving::GlyphTable.new,
                     font_manager: Clef::Engraving::FontManager.new)
        @style = style
        @glyph_table = glyph_table
        @font_manager = font_manager
      end

      # @param _score [Clef::Core::Score]
      # @param _path [String]
      def render(_score, _path, **_options)
        raise NotImplementedError
      end
    end
  end
end
