# frozen_string_literal: true

module Clef
  module Renderer
    module NotationHelpers
      ACCIDENTAL_GLYPH_KEYS = {
        -2 => :accidental_double_flat,
        -1 => :accidental_flat,
        0 => :accidental_natural,
        1 => :accidental_sharp,
        2 => :accidental_double_sharp
      }.freeze
      ACCIDENTAL_FALLBACK = {
        -2 => "bb",
        -1 => "b",
        0 => "n",
        1 => "#",
        2 => "##"
      }.freeze
      SHARP_ORDER = %i[f c g d a e b].freeze
      FLAT_ORDER = %i[b e a d g c f].freeze
      REST_LABELS = {
        whole: "W",
        half: "H",
        quarter: "r",
        eighth: "8",
        sixteenth: "16",
        thirty_second: "32",
        sixty_fourth: "64",
        one_twenty_eighth: "128",
        two_fifty_sixth: "256"
      }.freeze

      private

      def filled_notehead?(duration)
        !%i[whole half].include?(duration.base)
      end

      def stem_required?(duration)
        duration.base != :whole
      end

      def flag_required?(duration)
        %i[eighth sixteenth thirty_second sixty_fourth one_twenty_eighth two_fifty_sixth].include?(duration.base)
      end

      def beamable?(element)
        element.is_a?(Clef::Core::Note) && flag_required?(element.duration)
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
        chord.sorted_pitches.map { |pitch| Clef::Core::Note.new(pitch, chord.duration) }
      end

      def chord_stem_anchor_note(notes, direction)
        return notes.min_by { |note| note.pitch.to_midi } if direction == :up

        notes.max_by { |note| note.pitch.to_midi }
      end

      def chord_stem_length(notes, clef, direction)
        notes.map { |note| Clef::Layout::Stem.length(note, clef, direction) }.max
      end

      def key_signature_alterations(key_signature)
        return {} unless key_signature

        accidentals = key_signature.accidentals
        order = (accidentals[:type] == :sharp) ? SHARP_ORDER : FLAT_ORDER
        alteration = (accidentals[:type] == :sharp) ? 1 : -1
        order.first(accidentals[:count].to_i).to_h { |note_name| [note_name, alteration] }
      end

      def accidental_for_pitch(pitch, key_signature, state)
        expected = key_signature_alterations(key_signature)[pitch.note_name] || 0
        current = state.fetch(pitch.note_name, expected)
        return nil if current == pitch.alteration

        state[pitch.note_name] = pitch.alteration
        pitch.alteration
      end

      def rest_label(duration)
        REST_LABELS.fetch(duration.base)
      end

      def element_notes(element)
        case element
        when Clef::Core::Note then [element]
        when Clef::Core::Chord then chord_notes(element)
        when Clef::Core::Tuplet then element.elements.flat_map { |child| element_notes(child) }
        else []
        end
      end

      def dynamic_text(dynamic)
        dynamic.type.to_s
      end

      def flatten_elements(elements)
        elements.flat_map do |element|
          element.is_a?(Clef::Core::Tuplet) ? flatten_elements(element.elements) : element
        end
      end

      def lyric_elements(elements)
        flatten_elements(elements).select do |element|
          element.is_a?(Clef::Core::Note) || element.is_a?(Clef::Core::Chord)
        end
      end
    end
  end
end
