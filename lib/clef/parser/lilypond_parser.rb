# frozen_string_literal: true

module Clef
  module Parser
    class LilypondParser
      SUPPORTED_COMMANDS = %w[\\clef \\key \\major \\minor \\time \\tempo \\relative \\new].freeze

      attr_reader :warnings

      def initialize
        @warnings = []
      end

      # @param input [String]
      # @return [Clef::Core::Score]
      def parse(input)
        cleaned = strip_comments(input)
        @warnings = unsupported_command_warnings(cleaned)
        clef = extract_clef(cleaned)
        key_tonic = extract_key_tonic(cleaned)
        mode = extract_mode(cleaned)
        time_numerator, time_denominator = extract_time(cleaned)
        tempo_unit, tempo_bpm = extract_tempo(cleaned)
        note_stream = extract_note_stream(cleaned)

        score = Clef.score do
          tempo beat_unit: tempo_unit, bpm: tempo_bpm if tempo_bpm
          staff :staff1, clef: clef do
            key key_tonic, mode
            time time_numerator, time_denominator
            play note_stream
          end
        end
        Clef.plugins.run_hook(:on_after_parse, score)
        score
      end

      private

      def extract_note_stream(input)
        body = first_braced_body(input)
        body = relativize_body(input, body) if input.match?(/\\relative\b/)
        tokens = LilypondLexer.new.tokenize(body)
        tokens.select { |token| token.match?(/\A<|\A[a-g]|\Ar|\A\|/) }.join(" ")
      end

      def extract_key_tonic(input)
        match = /\\key\s+([a-g](?:isis|eses|is|es)?)/.match(input)
        tonic = (match && match[1]) || "c"
        Clef::Core::Pitch.parse_any(tonic)
      end

      def extract_mode(input)
        match = /\\key\s+[a-g](?:isis|eses|is|es)?\s+\\(major|minor)/.match(input)
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

      def extract_tempo(input)
        match = /\\tempo\s+(\d+)\s*=\s*(\d+)/.match(input)
        return [nil, nil] unless match

        [Clef::Core::Duration.from_lilypond(match[1].to_i), match[2].to_i]
      end

      def unsupported_command_warnings(input)
        LilypondLexer.new.tokenize(input).grep(/\A\\/).uniq.filter_map do |command|
          next if SUPPORTED_COMMANDS.include?(command)

          "unsupported LilyPond command ignored: #{command}"
        end
      end

      def strip_comments(input)
        input.to_s.gsub(/%\{.*?%\}/m, "").each_line.map { |line| line.sub(/%.*/, "") }.join
      end

      def first_braced_body(input)
        start_index = input.index("{")
        return "" unless start_index

        depth = 0
        index = start_index
        while index < input.length
          char = input[index]
          depth += 1 if char == "{"
          depth -= 1 if char == "}"
          return input[(start_index + 1)...index] if depth.zero?

          index += 1
        end
        ""
      end

      def relativize_body(input, body)
        match = /\\relative\s+([a-g](?:isis|eses|is|es)?[',]*)/.match(input)
        return body unless match

        previous = Clef::Core::Pitch.parse(match[1])
        LilypondLexer.new.tokenize(body).map do |token|
          if (note_match = /\A([a-g](?:isis|eses|is|es)?)(\d*\.*~?)\z/.match(token))
            previous = closest_relative_pitch(note_match[1], previous)
            "#{previous.to_lilypond}#{note_match[2]}"
          else
            token
          end
        end.join(" ")
      end

      def closest_relative_pitch(note_name, previous)
        base = Clef::Core::Pitch.parse(note_name)
        candidates = ((previous.octave - 2)..(previous.octave + 2)).map do |octave|
          Clef::Core::Pitch.new(base.note_name, octave, alteration: base.alteration)
        end
        candidates.min_by { |candidate| (candidate.semitones - previous.semitones).abs }
      end
    end
  end
end
