# frozen_string_literal: true

module Clef
  module Renderer
    module NotationHelpers
      ACCIDENTAL_GLYPH_KEYS = {
        -2 => :accidental_double_flat,
        -1 => :accidental_flat,
        1 => :accidental_sharp,
        2 => :accidental_double_sharp
      }.freeze
      ACCIDENTAL_FALLBACK = {
        -2 => "bb",
        -1 => "b",
        1 => "#",
        2 => "##"
      }.freeze

      private

      def filled_notehead?(duration)
        !%i[whole half].include?(duration.base)
      end

      def stem_required?(duration)
        duration.base != :whole
      end

      def duration_spacing(element)
        style.min_note_spacing * (element.length.to_f / Rational(1, 4).to_f)
      end

      def diatonic_step(pitch)
        note_index = Clef::Core::Pitch::VALID_NOTE_NAMES.index(pitch.note_name)
        (pitch.octave * 7) + note_index
      end

      # The staff baseline is the top line.
      # vertical_axis: +1 for PDF coordinates, -1 for SVG coordinates.
      def calculate_pitch_y(pitch, baseline, clef, vertical_axis:)
        reference = clef.reference_pitch
        diatonic = diatonic_step(pitch) - diatonic_step(reference)
        bottom_line = baseline - (vertical_axis * style.staff_space * 4)
        reference_y = bottom_line + (clef.reference_line * vertical_axis * style.staff_space)
        reference_y - (diatonic * (style.staff_space / 2.0))
      end

      def accidental_glyph_key(alteration)
        ACCIDENTAL_GLYPH_KEYS[alteration]
      end

      def accidental_text(alteration)
        ACCIDENTAL_FALLBACK.fetch(alteration)
      end

      def chord_notes(chord)
        chord.pitches.map { |pitch| Clef::Core::Note.new(pitch, chord.duration) }
      end

      def chord_stem_anchor_note(notes, direction)
        return notes.min_by { |note| note.pitch.to_midi } if direction == :up

        notes.max_by { |note| note.pitch.to_midi }
      end

      def chord_stem_length(notes, clef, direction)
        notes.map { |note| Clef::Layout::Stem.length(note, clef, direction) }.max
      end
    end
  end
end
