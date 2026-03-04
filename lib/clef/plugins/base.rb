# frozen_string_literal: true

module Clef
  module Plugins
    class Base
      class << self
        # @return [String]
        def plugin_name
          name.split("::").last.downcase
        end
      end

      # @param _score [Clef::Core::Score]
      def on_before_layout(_score); end

      # @param _layout_result [Hash]
      def on_after_layout(_layout_result); end

      # @param _renderer [Object]
      def on_before_render(_renderer); end

      # @param _glyph_table [Clef::Engraving::GlyphTable]
      def register_glyphs(_glyph_table); end
    end
  end
end
