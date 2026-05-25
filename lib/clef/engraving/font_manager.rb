# frozen_string_literal: true

module Clef
  module Engraving
    class FontManager
      attr_reader :font_path

      # @param font_path [String]
      def initialize(font_path: default_font_path)
        @font_path = font_path
      end

      # @return [Boolean]
      def font_available?
        File.exist?(font_path)
      end

      # @param pdf [Prawn::Document]
      # @param family_name [String]
      # @return [String]
      def register_with(pdf, family_name: "Bravura")
        return "Helvetica" unless font_available?

        pdf.font_families.update(family_name => {normal: font_path})
        family_name
      end

      private

      def default_font_path
        File.expand_path("../../../fonts/bravura/Bravura.otf", __dir__)
      end
    end
  end
end
