# frozen_string_literal: true

module Clef
  module Parser
    class LilypondLexer
      TOKEN_REGEX = /\\[a-zA-Z]+|\{\}|\{|\}|<[^>]+>\d+\.*|[a-g](?:isis|eses|is|es)?[',]*\d+\.*|r\d+\.*|\|/m

      # @param input [String]
      # @return [Array<String>]
      def tokenize(input)
        sanitized = strip_comments(input)
        sanitized.scan(TOKEN_REGEX)
      end

      private

      def strip_comments(input)
        input.to_s.each_line.map { |line| line.sub(/%.*/, "") }.join
      end
    end
  end
end
