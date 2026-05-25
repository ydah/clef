# frozen_string_literal: true

module Clef
  module Core
    class Pitch
      include Comparable

      NOTE_VALUES = {
        c: 0,
        d: 2,
        e: 4,
        f: 5,
        g: 7,
        a: 9,
        b: 11
      }.freeze
      VALID_NOTE_NAMES = NOTE_VALUES.keys.freeze
      ALTERATION_SUFFIX = {
        -2 => "eses",
        -1 => "es",
        0 => "",
        1 => "is",
        2 => "isis"
      }.freeze
      SUFFIX_ALTERATION = ALTERATION_SUFFIX.invert.freeze
      MIDI_CLASS_TO_PITCH = {
        0 => [:c, 0],
        1 => [:c, 1],
        2 => [:d, 0],
        3 => [:d, 1],
        4 => [:e, 0],
        5 => [:f, 0],
        6 => [:f, 1],
        7 => [:g, 0],
        8 => [:g, 1],
        9 => [:a, 0],
        10 => [:a, 1],
        11 => [:b, 0]
      }.freeze
      MIDI_CLASS_TO_FLAT_PITCH = {
        0 => [:c, 0],
        1 => [:d, -1],
        2 => [:d, 0],
        3 => [:e, -1],
        4 => [:e, 0],
        5 => [:f, 0],
        6 => [:g, -1],
        7 => [:g, 0],
        8 => [:a, -1],
        9 => [:a, 0],
        10 => [:b, -1],
        11 => [:b, 0]
      }.freeze
      SCIENTIFIC_PITCH_REGEX = /\A([A-Ga-g])([#b]{0,2})(-?\d+)\z/
      LILYPOND_PITCH_REGEX = /\A([a-g])(eses|isis|es|is)?([',]*)\z/
      TRANSPOSE_PREFERENCES = %i[sharp flat].freeze
      MIDI_RANGE = (0..127)

      attr_reader :note_name, :octave, :alteration

      # @param note_name [Symbol]
      # @param octave [Integer]
      # @param alteration [Integer]
      def initialize(note_name, octave, alteration: 0)
        validate_note_name!(note_name)
        validate_octave!(octave)
        validate_alteration!(alteration)

        @note_name = note_name
        @octave = octave
        @alteration = alteration
        freeze
      end

      # @return [Integer]
      def to_midi
        midi = semitones + 12
        raise RangeError, "MIDI pitch out of range: #{midi}" unless MIDI_RANGE.cover?(midi)

        midi
      end

      # @return [Integer]
      def semitones
        octave * 12 + NOTE_VALUES.fetch(note_name) + alteration
      end

      # @param tuning [Float]
      # @return [Float]
      def to_frequency(tuning: 440.0)
        tuning * (2.0**((to_midi - 69) / 12.0))
      end

      # @param semitones_or_interval [Integer, #semitones]
      # @param prefer [Symbol]
      # @return [Pitch]
      def transpose(semitones_or_interval, prefer: :sharp)
        validate_transpose_preference!(prefer)

        target_midi = to_midi + normalize_semitones(semitones_or_interval)
        raise RangeError, "MIDI pitch out of range: #{target_midi}" unless MIDI_RANGE.cover?(target_midi)

        octave = (target_midi / 12) - 1
        pitch_map = (prefer == :flat) ? MIDI_CLASS_TO_FLAT_PITCH : MIDI_CLASS_TO_PITCH
        note_name, alteration = pitch_map.fetch(target_midi % 12)
        self.class.new(note_name, octave, alteration: alteration)
      end

      # @param other [Pitch]
      # @return [Boolean]
      def enharmonic?(other)
        other.is_a?(self.class) && semitones == other.semitones
      end

      # @param other [Pitch]
      # @return [Integer, nil]
      def <=>(other)
        return nil unless other.is_a?(self.class)

        semitones <=> other.semitones
      end

      # @return [String]
      def to_lilypond
        [note_name, ALTERATION_SUFFIX.fetch(alteration), octave_marks].join
      end

      # @param str [String]
      # @return [Pitch]
      def self.parse(str)
        raise ArgumentError, "pitch string must be a String" unless str.is_a?(String)

        match = LILYPOND_PITCH_REGEX.match(str)
        raise ArgumentError, "invalid lilypond pitch: #{str}" unless match

        note_name = match[1].to_sym
        suffix = match[2] || ""
        octave = 3 + match[3].count("'") - match[3].count(",")
        new(note_name, octave, alteration: SUFFIX_ALTERATION.fetch(suffix))
      end

      # @param str [String]
      # @return [Pitch]
      def self.parse_scientific(str)
        raise ArgumentError, "pitch string must be a String" unless str.is_a?(String)

        match = SCIENTIFIC_PITCH_REGEX.match(str)
        raise ArgumentError, "invalid scientific pitch: #{str}" unless match

        note_name = match[1].downcase.to_sym
        alteration = {"" => 0, "#" => 1, "##" => 2, "b" => -1, "bb" => -2}.fetch(match[2])
        new(note_name, match[3].to_i, alteration: alteration)
      end

      # @param value [String, Symbol, Pitch]
      # @return [Pitch]
      def self.parse_any(value)
        return value if value.is_a?(self)
        return parse(value.to_s.downcase) if value.is_a?(Symbol)

        parse_scientific(value)
      rescue ArgumentError
        parse(value.to_s.downcase)
      end

      private

      def octave_marks
        delta = octave - 3
        return "'" * delta if delta.positive?

        "," * delta.abs
      end

      def normalize_semitones(arg)
        return arg.semitones if arg.respond_to?(:semitones)

        Integer(arg)
      rescue ArgumentError, TypeError
        raise ArgumentError, "transpose expects Integer or object responding to #semitones"
      end

      def validate_note_name!(note_name)
        return if VALID_NOTE_NAMES.include?(note_name)

        raise ArgumentError, "invalid note name: #{note_name.inspect}"
      end

      def validate_octave!(octave)
        return if octave.is_a?(Integer)

        raise ArgumentError, "octave must be an Integer"
      end

      def validate_alteration!(alteration)
        return if (-2..2).cover?(alteration)

        raise ArgumentError, "alteration must be between -2 and 2"
      end

      def validate_transpose_preference!(prefer)
        return if TRANSPOSE_PREFERENCES.include?(prefer)

        raise ArgumentError, "transpose prefer must be :sharp or :flat"
      end
    end
  end
end
