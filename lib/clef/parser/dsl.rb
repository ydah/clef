# frozen_string_literal: true

module Clef
  module Parser
    module DSL
      class Error < StandardError; end

      class ScoreBuilder
        attr_reader :score

        def initialize
          @score = Clef::Core::Score.new
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
          build_staff(staff, &block)
          @default_group.add_staff(staff)
          staff
        rescue NoMethodError => e
          raise Error, "invalid DSL method in staff block: #{e.name}"
        end

        # @param bracket_type [Symbol]
        def staff_group(bracket_type, &block)
          group = Clef::Core::StaffGroup.new([], bracket_type: bracket_type)
          GroupBuilder.new(group).instance_eval(&block)
          score.add_staff_group(group)
          group
        rescue NoMethodError => e
          raise Error, "invalid DSL method in staff_group block: #{e.name}"
        end

        # @return [Clef::Core::Score]
        def build
          score
        end

        private

        def build_staff(staff, &block)
          return unless block

          StaffBuilder.new(staff).instance_eval(&block)
        end
      end

      class GroupBuilder
        def initialize(group)
          @group = group
        end

        # @param id [Symbol]
        # @param name [String, nil]
        # @param clef [Symbol]
        def staff(id, name: nil, clef: :treble, &block)
          staff = Clef::Core::Staff.new(id, name: name, clef: Clef::Core::Clef.new(clef))
          StaffBuilder.new(staff).instance_eval(&block) if block
          @group.add_staff(staff)
          staff
        end
      end

      class StaffBuilder
        def initialize(staff)
          @staff = staff
          @current_measure = nil
          @next_measure_number = 1
          @lyrics = []
        end

        # @param tonic [Symbol, Clef::Core::Pitch]
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

          VoiceBuilder.new(voice).instance_eval(&block)
          voice
        rescue NoMethodError => e
          raise Error, "invalid DSL method in voice block: #{e.name}"
        end

        # @param lilypond_string [String]
        def play(lilypond_string)
          segments = split_measures(lilypond_string)
          segments.each_with_index do |segment, idx|
            measure = ensure_measure
            VoiceBuilder.new(measure.voice(:default)).notes(segment)
            advance_measure if idx < segments.length - 1
          end
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

          @current_measure = Clef::Core::Measure.new(@next_measure_number, time_signature: @staff.time_signature)
          @current_measure.key_signature = @staff.key_signature
          @current_measure.clef = @staff.clef
          @staff.add_measure(@current_measure)
          @next_measure_number += 1
          @current_measure
        end

        def advance_measure
          @current_measure = nil
        end

        def split_measures(input)
          input.to_s.split("|").map(&:strip).reject(&:empty?)
        end
      end

      class VoiceBuilder
        def initialize(voice)
          @voice = voice
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
          @voice.add(Clef::Core::Rest.new(duration))
        end

        # @param pitch_strs [Array<String>]
        # @param duration_sym [Symbol]
        # @param opts [Hash]
        def chord(pitch_strs, duration_sym, **opts)
          duration = Clef::Core::Duration.new(duration_sym, dots: opts.fetch(:dots, 0))
          pitches = pitch_strs.map { |pitch| parse_pitch(pitch) }
          @voice.add(Clef::Core::Chord.new(pitches, duration))
        end

        # @param lilypond_string [String]
        def notes(lilypond_string)
          parse_tokens(lilypond_string).each { |token| add_token(token) }
        end

        # @param actual [Integer]
        # @param normal [Integer]
        def tuplet(actual, normal)
          raise ArgumentError, "tuplet values must be positive" unless actual.positive? && normal.positive?

          return unless block_given?

          yield
        end

        private

        def parse_tokens(input)
          input.to_s.split(/\s+/).reject(&:empty?)
        end

        def add_token(token)
          return if token == "|"

          if token.start_with?("r")
            add_rest_token(token)
          elsif token.start_with?("<")
            add_chord_token(token)
          else
            add_note_token(token)
          end
        rescue StandardError => e
          raise Error, "failed to parse token '#{token}': #{e.message}"
        end

        def add_rest_token(token)
          match = /\Ar(\d+)(\.*)\z/.match(token)
          raise ArgumentError, "invalid rest token" unless match

          duration = Clef::Core::Duration.from_lilypond(match[1].to_i, match[2].length)
          @voice.add(Clef::Core::Rest.new(duration))
        end

        def add_chord_token(token)
          match = /\A<([^>]+)>(\d+)(\.*)\z/.match(token)
          raise ArgumentError, "invalid chord token" unless match

          pitches = match[1].split(/\s+/).map { |value| parse_pitch(value) }
          duration = Clef::Core::Duration.from_lilypond(match[2].to_i, match[3].length)
          @voice.add(Clef::Core::Chord.new(pitches, duration))
        end

        def add_note_token(token)
          match = /\A([a-g](?:isis|eses|is|es)?[',]*)(\d+)(\.*)\z/.match(token)
          raise ArgumentError, "invalid note token" unless match

          pitch = parse_pitch(match[1])
          duration = Clef::Core::Duration.from_lilypond(match[2].to_i, match[3].length)
          @voice.add(Clef::Core::Note.new(pitch, duration))
        end

        def parse_pitch(value)
          parse_scientific_pitch(value) || Clef::Core::Pitch.parse(value.downcase)
        end

        def parse_scientific_pitch(value)
          match = /\A([A-Ga-g])([#b]{0,2})(-?\d+)\z/.match(value)
          return nil unless match

          note_name = match[1].downcase.to_sym
          alteration = { "" => 0, "#" => 1, "##" => 2, "b" => -1, "bb" => -2 }.fetch(match[2])
          Clef::Core::Pitch.new(note_name, match[3].to_i, alteration: alteration)
        end
      end
    end
  end
end
