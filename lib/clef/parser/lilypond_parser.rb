# frozen_string_literal: true

module Clef
  module Parser
    class LilypondParser
      SUPPORTED_COMMANDS = %w[\\clef \\key \\major \\minor \\time \\tempo \\relative \\new \\with].freeze
      DYNAMIC_COMMANDS = Clef::Notation::Dynamic::TYPES.map { |type| "\\#{type}" }.freeze
      STAFF_COMMAND = /\\new\s+(?:Staff|PianoStaff|StaffGroup)/

      attr_reader :warnings, :plugins

      # @param plugins [Clef::Plugins::Registry]
      def initialize(plugins: Clef.plugins)
        @plugins = plugins
        @warnings = []
      end

      # @param input [String]
      # @return [Clef::Core::Score]
      def parse(input)
        cleaned = strip_comments(input)
        @warnings = unsupported_command_warnings(cleaned)
        score = build_score(cleaned)
        plugins.run_hook(:on_after_parse, score)
        score
      end

      private

      def build_score(input)
        staff_blocks = extract_staff_blocks(input)
        return build_single_staff_score(input) if staff_blocks.empty?

        global_tempo_unit, global_tempo_bpm = extract_tempo(input)
        use_staff_group = staff_group_input?(input)
        parser = self
        Clef.score(plugins: plugins) do
          tempo beat_unit: global_tempo_unit, bpm: global_tempo_bpm if global_tempo_bpm
          if use_staff_group
            staff_group :bracket do
              staff_blocks.each_with_index { |block, index| parser.send(:build_staff_from_block, self, block, index) }
            end
          else
            staff_blocks.each_with_index { |block, index| parser.send(:build_staff_from_block, self, block, index) }
          end
        end
      end

      def build_single_staff_score(input)
        clef = extract_clef(input)
        key_tonic = extract_key_tonic(input)
        mode = extract_mode(input)
        time_numerator, time_denominator = extract_time(input)
        tempo_unit, tempo_bpm = extract_tempo(input)
        voice_streams = extract_voice_streams(first_braced_body(input), context: input)
        parser = self

        Clef.score(plugins: plugins) do
          tempo beat_unit: tempo_unit, bpm: tempo_bpm if tempo_bpm
          staff :staff1, clef: clef do
            key key_tonic, mode
            time time_numerator, time_denominator
            parser.send(:add_voice_streams, self, voice_streams)
          end
        end
      end

      def build_staff_from_block(builder, block, index)
        context = "#{block[:header]}\n#{block[:body]}"
        clef = extract_clef(context)
        key_tonic = extract_key_tonic(context)
        mode = extract_mode(context)
        time_numerator, time_denominator = extract_time(context)
        voice_streams = extract_voice_streams(block[:body], context: context)
        staff_id = :"staff#{index + 1}"
        parser = self

        builder.staff staff_id, clef: clef do
          key key_tonic, mode
          time time_numerator, time_denominator
          parser.send(:add_voice_streams, self, voice_streams)
        end
      end

      def add_voice_streams(builder, voice_streams)
        streams = voice_streams.map { |stream| measure_segments(stream) }
        measure_count = streams.map(&:length).max.to_i
        measure_count.times do |measure_index|
          builder.measure(measure_index + 1) do |staff_builder|
            streams.each_with_index do |segments, voice_index|
              segment = segments[measure_index]
              next if segment.to_s.empty?

              staff_builder.voice(voice_id_for(voice_index)) { notes segment }
            end
          end
        end
      end

      def measure_segments(stream)
        stream.to_s.split("|").map(&:strip).reject(&:empty?)
      end

      def voice_id_for(index)
        index.zero? ? :default : :"voice#{index + 1}"
      end

      def extract_staff_blocks(input)
        blocks = []
        scanner_index = 0
        while (match = input.match(STAFF_COMMAND, scanner_index))
          command_start = match.begin(0)
          brace_start = input.index("{", match.end(0))
          break unless brace_start

          body, body_end = braced_body_at(input, brace_start)
          header = input[command_start...brace_start]
          blocks << {header: header, body: body}
          scanner_index = body_end + 1
        end
        blocks
      end

      def staff_group_input?(input)
        input.match?(/\\new\s+(?:StaffGroup|PianoStaff)\b/) || input.include?("<<")
      end

      def extract_voice_streams(body, context: body)
        simultaneous = first_simultaneous_body(body)
        streams = if simultaneous
          braced_bodies(simultaneous)
        elsif (inner = braced_bodies(body).first)
          [inner]
        else
          [body]
        end
        streams.map { |stream| note_stream(stream, context: context) }.reject(&:empty?)
      end

      def note_stream(input, context:)
        body = context.match?(/\\relative\b/) ? relativize_body(context, input) : input
        tokens = LilypondLexer.new.tokenize(body)
        tokens.select do |token|
          token.match?(/\A<|\A[a-g]|\Ar|\A\||\A[()~\[\]]|\A(?:--|->|-\.)\z/) || DYNAMIC_COMMANDS.include?(token)
        end.join(" ")
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
        clef = (match && match[1]&.to_sym) || :treble
        return clef if Clef::Core::Clef::TYPES.include?(clef)

        warnings << "unsupported clef ignored: #{clef}"
        :treble
      end

      def extract_tempo(input)
        match = /\\tempo\s+(\d+)\s*=\s*(\d+)/.match(input)
        return [nil, nil] unless match

        [Clef::Core::Duration.from_lilypond(match[1].to_i), match[2].to_i]
      end

      def unsupported_command_warnings(input)
        seen = {}
        LilypondLexer.new.tokenize_with_locations(input).select { |token| token.value.start_with?("\\") }.filter_map do |token|
          command = token.value
          next if SUPPORTED_COMMANDS.include?(command) || DYNAMIC_COMMANDS.include?(command)
          next if seen[command]

          seen[command] = true
          "unsupported LilyPond command ignored at line #{token.line}, column #{token.column}: #{command}"
        end
      end

      def strip_comments(input)
        input.to_s.gsub(/%\{.*?%\}/m, "").each_line.map { |line| line.sub(/%.*/, "") }.join
      end

      def first_braced_body(input)
        start_index = input.index("{")
        return "" unless start_index

        braced_body_at(input, start_index).first
      end

      def braced_body_at(input, start_index)
        depth = 0
        index = start_index
        while index < input.length
          char = input[index]
          depth += 1 if char == "{"
          depth -= 1 if char == "}"
          return [input[(start_index + 1)...index], index] if depth.zero?

          index += 1
        end
        ["", input.length]
      end

      def first_simultaneous_body(input)
        start_index = input.index("<<")
        return nil unless start_index

        depth = 0
        index = start_index
        while index < input.length - 1
          token = input[index, 2]
          depth += 1 if token == "<<"
          depth -= 1 if token == ">>"
          return input[(start_index + 2)...index] if depth.zero?

          index += 1
        end
        nil
      end

      def braced_bodies(input)
        bodies = []
        scanner_index = 0
        while (brace_start = input.index("{", scanner_index))
          body, body_end = braced_body_at(input, brace_start)
          bodies << body
          scanner_index = body_end + 1
        end
        bodies
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
