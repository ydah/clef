# frozen_string_literal: true

module Clef
  module Parser
    class LilypondLexer
      Token = Struct.new(:value, :line, :column, keyword_init: true) do
        def to_s
          value
        end

        def match?(*args)
          value.match?(*args)
        end

        def ==(other)
          value == other || super
        end
      end

      TOKEN_REGEX = /
        \\[a-zA-Z]+ |
        << | >> |
        \{\} | \{ | \} |
        <[^>]+>\d*\.*~? |
        [a-g](?:isis|eses|is|es)?[',]*\d*\.*~? |
        r\d*\.* |
        -- | -> | -\. |
        [~()\[\]|]
      /mx

      # @param input [String]
      # @return [Array<String>]
      def tokenize(input)
        tokenize_with_locations(input).map(&:value)
      end

      # @param input [String]
      # @return [Array<Token>]
      def tokenize_with_locations(input)
        sanitized = strip_comments(input)
        sanitized.enum_for(:scan, TOKEN_REGEX).map do
          value = Regexp.last_match[0]
          line, column = location_for(sanitized, Regexp.last_match.begin(0))
          Token.new(value: value, line: line, column: column)
        end
      end

      private

      def strip_comments(input)
        input.to_s.gsub(/%\{.*?%\}/m, "").each_line.map { |line| line.sub(/%.*/, "") }.join
      end

      def location_for(input, offset)
        prefix = input[0...offset]
        line = prefix.count("\n") + 1
        column = offset - (prefix.rindex("\n") || -1)
        [line, column]
      end
    end
  end
end
