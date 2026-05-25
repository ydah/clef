# frozen_string_literal: true

module Clef
  module Parser
    module DSL
      class Error < StandardError; end

      module BlockEvaluation
        private

        def evaluate_block(target, &block)
          return unless block
          return block.call(target) if block.arity == 1

          target.instance_eval(&block)
        end

        def method_missing(name, *_args, &_block)
          raise Error, "invalid DSL method: #{name}"
        end

        def respond_to_missing?(_name, _include_private = false)
          false
        end
      end

      class ScoreBuilder
        include BlockEvaluation

        attr_reader :score

        def initialize(plugins: Clef.plugins)
          @score = Clef::Core::Score.new
          @score.plugins = plugins
          @default_group = Clef::Core::StaffGroup.new([], bracket_type: :none)
          score.add_staff_group(@default_group)
        end

        # @param value [String]
        def title(value)
          score.title = value.to_s
        end

        # @param value [String]
        def composer(value)
          score.composer = value.to_s
        end

        # @param beat_unit [Symbol, Clef::Core::Duration]
        # @param bpm [Integer]
        def tempo(beat_unit:, bpm:)
          duration = beat_unit.is_a?(Clef::Core::Duration) ? beat_unit : Clef::Core::Duration.new(beat_unit)
          score.tempo = Clef::Core::Tempo.new(beat_unit: duration, bpm: bpm)
        end

        # @param id [Symbol]
        # @param name [String, nil]
        # @param clef [Symbol]
        def staff(id, name: nil, clef: :treble, &block)
          staff = Clef::Core::Staff.new(id, name: name, clef: Clef::Core::Clef.new(clef))
          evaluate_block(StaffBuilder.new(staff), &block)
          @default_group.add_staff(staff)
          staff
        end

        # @param bracket_type [Symbol]
        def staff_group(bracket_type, &block)
          raise Error, "staff_group requires a block" unless block

          group = Clef::Core::StaffGroup.new([], bracket_type: bracket_type)
          evaluate_block(GroupBuilder.new(group), &block)
          score.add_staff_group(group)
          group
        end

        # @return [Clef::Core::Score]
        def build
          score
        end
      end

      class GroupBuilder
        include BlockEvaluation

        def initialize(group)
          @group = group
        end

        # @param id [Symbol]
        # @param name [String, nil]
        # @param clef [Symbol]
        def staff(id, name: nil, clef: :treble, &block)
          staff = Clef::Core::Staff.new(id, name: name, clef: Clef::Core::Clef.new(clef))
          evaluate_block(StaffBuilder.new(staff), &block)
          @group.add_staff(staff)
          staff
        end
      end

      class StaffBuilder
        include BlockEvaluation

        def initialize(staff)
          @staff = staff
          @current_measure = nil
          @next_measure_number = 1
          @lyrics = []
        end

        # @param tonic [Symbol, String, Clef::Core::Pitch]
        # @param mode [Symbol]
        def key(tonic, mode = :major)
          @staff.key_signature = Clef::Core::KeySignature.new(tonic, mode)
        end

        # @param numerator [Integer]
        # @param denominator [Integer]
        def time(numerator, denominator)
          @staff.time_signature = Clef::Core::TimeSignature.new(numerator, denominator)
        end

        # @param id [Symbol]
        def voice(id = :default, &block)
          measure = ensure_measure
          voice = measure.voice(id)
          return voice unless block

          evaluate_block(VoiceBuilder.new(voice), &block)
          validate_measure_overflow!(measure)
          voice
        end

        # @param lilypond_string [String]
        def play(lilypond_string)
          segments = split_measures(lilypond_string)
          segments.each_with_index do |segment, idx|
            measure = ensure_measure
            VoiceBuilder.new(measure.voice(:default)).notes(segment)
            validate_measure_overflow!(measure)
            advance_measure if idx < segments.length - 1
          end
        end

        def bar
          advance_measure
        end

        # @param number [Integer, nil]
        def measure(number = nil, &block)
          @current_measure = new_measure(number || @next_measure_number)
          evaluate_block(self, &block)
          @current_measure
        ensure
          advance_measure
        end

        # @param voice_id [Symbol]
        # @param text [String]
        def lyrics(voice_id, text)
          @lyrics << Clef::Notation::Lyric.new(voice_id, text)
          @staff.metadata ||= {}
          @staff.metadata[:lyrics] = @lyrics
        end

        private

        def ensure_measure
          return @current_measure if @current_measure

          @current_measure = new_measure(@next_measure_number)
        end

        def new_measure(number)
          measure = Clef::Core::Measure.new(number, time_signature: @staff.time_signature)
          measure.key_signature = @staff.key_signature
          measure.clef = @staff.clef
          @staff.add_measure(measure)
          @next_measure_number = measure.number + 1
          measure
        end

        def advance_measure
          @current_measure = nil
        end

        def split_measures(input)
          input.to_s.split("|").map(&:strip).reject(&:empty?)
        end

        def validate_measure_overflow!(measure)
          ids = measure.overflowing_voice_ids
          return if ids.empty?

          raise Error, "measure #{measure.number} voice #{ids.join(", ")} exceeds time signature length"
        end
      end

      class VoiceBuilder
        include BlockEvaluation

        def initialize(voice)
          @voice = voice
          @last_duration = Clef::Core::Duration.quarter
          @pending_tie = false
          @pending_articulations = []
          @open_slur = false
          @open_beam = false
          @last_note = nil
        end

        # @param pitch_str [String]
        # @param duration_sym [Symbol]
        # @param opts [Hash]
        def note(pitch_str, duration_sym, **opts)
          pitch = parse_pitch(pitch_str)
          duration = Clef::Core::Duration.new(duration_sym, dots: opts.fetch(:dots, 0))
          articulations = Array(opts.fetch(:articulations, []))
          @voice.add(Clef::Core::Note.new(pitch, duration, articulations: articulations, tied: opts[:tied]))
        end

        # @param duration_sym [Symbol]
        # @param opts [Hash]
        def rest(duration_sym, **opts)
          duration = Clef::Core::Duration.new(duration_sym, dots: opts.fetch(:dots, 0))
          @voice.add(Clef::Core::Rest.new(duration, kind: opts.fetch(:kind, :visible), measures: opts.fetch(:measures, 1)))
        end

        # @param pitch_strs [Array<String>]
        # @param duration_sym [Symbol]
        # @param opts [Hash]
        def chord(pitch_strs, duration_sym, **opts)
          duration = Clef::Core::Duration.new(duration_sym, dots: opts.fetch(:dots, 0))
          pitches = pitch_strs.map { |pitch| parse_pitch(pitch) }
          @voice.add(Clef::Core::Chord.new(pitches, duration))
        end

        # @param type [Symbol]
        def dynamic(type)
          @voice.add(Clef::Notation::Dynamic.new(type))
        end

        # @param beat_unit [Symbol, Clef::Core::Duration]
        # @param bpm [Integer]
        def tempo(beat_unit:, bpm:)
          duration = beat_unit.is_a?(Clef::Core::Duration) ? beat_unit : Clef::Core::Duration.new(beat_unit)
          @voice.add(Clef::Core::Tempo.new(beat_unit: duration, bpm: bpm))
        end

        # @param lilypond_string [String]
        def notes(lilypond_string)
          parse_tokens(lilypond_string).each { |token| add_token(token) }
        end

        # @param actual [Integer]
        # @param normal [Integer]
        def tuplet(actual, normal, &block)
          raise ArgumentError, "tuplet values must be positive" unless actual.positive? && normal.positive?
          return unless block_given?

          voice = Clef::Core::Voice.new(id: @voice.id)
          evaluate_block(self.class.new(voice), &block)
          @voice.add(Clef::Core::Tuplet.new(actual, normal, voice.elements))
        end

        private

        def parse_tokens(input)
          Clef::Parser::LilypondLexer.new.tokenize(input)
        end

        def add_token(token)
          token = token.to_s
          return if token == "|"
          return start_slur if token == "("
          return end_slur if token == ")"
          return start_beam if token == "["
          return end_beam if token == "]"
          return tie_next if token == "~"
          return add_pending_articulation(token) if articulation_token?(token)
          return add_command_token(token) if token.start_with?("\\")

          if token.start_with?("r")
            add_rest_token(token)
          elsif token.start_with?("<")
            add_chord_token(token)
          else
            add_note_token(token)
          end
        rescue => e
          raise Error, "failed to parse token '#{token}': #{e.message}"
        end

        def add_rest_token(token)
          match = /\Ar(\d*)(\.*)\z/.match(token)
          raise ArgumentError, "invalid rest token" unless match

          duration = duration_from_match(match[1], match[2])
          @voice.add(Clef::Core::Rest.new(duration))
        end

        def add_chord_token(token)
          token, tied = split_tie_suffix(token)
          match = /\A<([^>]+)>(\d*)(\.*)\z/.match(token)
          raise ArgumentError, "invalid chord token" unless match

          pitches = match[1].split(/\s+/).map { |value| parse_pitch(value) }
          duration = duration_from_match(match[2], match[3])
          @voice.add(Clef::Core::Chord.new(pitches, duration))
          tie_next if tied
        end

        def add_note_token(token)
          token, tied = split_tie_suffix(token)
          token, articulations = split_articulation_suffixes(token)
          @pending_articulations.concat(articulations)
          match = /\A([a-g](?:isis|eses|is|es)?[',]*)(\d*)(\.*)\z/.match(token)
          raise ArgumentError, "invalid note token" unless match

          pitch = parse_pitch(match[1])
          duration = duration_from_match(match[2], match[3])
          note = Clef::Core::Note.new(pitch, duration,
            articulations: consume_articulations,
            tied: consume_tie_state)
          note.slur_start = consume_slur_start
          note.beam_start = consume_beam_start
          @voice.add(note)
          @last_note = note
          tie_next if tied
        end

        def parse_pitch(value)
          Clef::Core::Pitch.parse_any(value)
        end

        def duration_from_match(number, dots)
          duration = if number.empty?
            @last_duration
          else
            Clef::Core::Duration.from_lilypond(number.to_i, dots.length)
          end
          @last_duration = duration
          duration
        end

        def split_tie_suffix(token)
          return [token.delete_suffix("~"), true] if token.end_with?("~")

          [token, false]
        end

        def split_articulation_suffixes(token)
          articulations = []
          loop do
            suffix = {"-." => :staccato, "->" => :accent, "--" => :tenuto}.find { |marker, _| token.end_with?(marker) }
            break unless suffix

            marker, articulation = suffix
            token = token.delete_suffix(marker)
            articulations << articulation
          end
          [token, articulations.reverse]
        end

        def articulation_token?(token)
          %w[-. -> --].include?(token)
        end

        def add_pending_articulation(token)
          articulation = {"-." => :staccato, "->" => :accent, "--" => :tenuto}.fetch(token)
          if @last_note
            @last_note.articulations << articulation
          else
            @pending_articulations << articulation
          end
        end

        def add_command_token(token)
          dynamic_name = token.delete_prefix("\\").to_sym
          return dynamic(dynamic_name) if Clef::Notation::Dynamic::TYPES.include?(dynamic_name)

          raise ArgumentError, "unsupported command token: #{token}"
        end

        def consume_articulations
          @pending_articulations.tap { @pending_articulations = [] }
        end

        def tie_next
          @last_note.tied = :start if @last_note
          @pending_tie = true
        end

        def consume_tie_state
          return false unless @pending_tie

          @pending_tie = false
          :stop
        end

        def start_slur
          @open_slur = true
        end

        def end_slur
          @last_note.slur_end = true if @last_note
        end

        def start_beam
          @open_beam = true
        end

        def end_beam
          @last_note.beam_end = true if @last_note
        end

        def consume_slur_start
          return false unless @open_slur

          @open_slur = false
          true
        end

        def consume_beam_start
          return false unless @open_beam

          @open_beam = false
          true
        end
      end
    end
  end
end
