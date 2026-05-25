# frozen_string_literal: true

module Clef
  module Notation
    class Lyric
      attr_reader :voice_id, :text, :syllables

      # @param voice_id [Symbol]
      # @param text [String]
      def initialize(voice_id, text)
        raise ArgumentError, "text must be String" unless text.is_a?(String)

        @voice_id = voice_id
        @text = text
        @syllables = parse_syllables(text)
      end

      private

      def parse_syllables(input)
        input
          .split(/\s+/)
          .flat_map { |token| lyric_token_parts(token) }
          .reject(&:empty?)
      end

      def lyric_token_parts(token)
        return [token] if %w[_ --].include?(token)

        token.split("-")
      end
    end
  end
end
