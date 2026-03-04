# frozen_string_literal: true

module Clef
  module Parser
    class LilypondParser
      # @param input [String]
      # @return [Clef::Core::Score]
      def parse(input)
        cleaned = input.to_s
        clef = extract_clef(cleaned)
        key_tonic = extract_key_tonic(cleaned)
        mode = extract_mode(cleaned)
        time_numerator, time_denominator = extract_time(cleaned)
        note_stream = extract_note_stream(cleaned)

        Clef.score do
          staff :staff1, clef: clef do
            key key_tonic, mode
            time time_numerator, time_denominator
            play note_stream
          end
        end
      end

      private

      def extract_note_stream(input)
        body = input[/\{(.+)\}/m, 1] || ""
        tokens = LilypondLexer.new.tokenize(body)
        tokens.select { |token| token.match?(/\A<|\A[a-g]|\Ar|\A\|/) }.join(" ")
      end

      def extract_key_tonic(input)
        match = /\\key\s+([a-g](?:is|es)?)/.match(input)
        tonic = (match && match[1]) || "c"
        Clef::Core::Pitch.parse(tonic)
      end

      def extract_mode(input)
        match = /\\key\s+[a-g](?:is|es)?\s+\\(major|minor)/.match(input)
        (match && match[1]&.to_sym) || :major
      end

      def extract_time(input)
        match = /\\time\s+(\d+)\/(\d+)/.match(input)
        return [4, 4] unless match

        [match[1].to_i, match[2].to_i]
      end

      def extract_clef(input)
        match = /\\clef\s+"?([a-z_]+)"?/.match(input)
        (match && match[1]&.to_sym) || :treble
      end
    end
  end
end
