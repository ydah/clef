# frozen_string_literal: true

require "prawn"

module Clef
  module Renderer
    class PdfRenderer < Base
      LEFT_PADDING = 80
      TOP_PADDING = 40

      # @param score [Clef::Core::Score]
      # @param path [String]
      # @param positions [Hash]
      def render(score, path, positions: nil, **_options)
        Prawn::Document.generate(path, page_size: style.page_size, margin: style.margin) do |pdf|
          prepare_canvas(pdf)
          draw_score(pdf, score, positions)
        end
      end

      # @param pdf [Prawn::Document]
      # @param score [Clef::Core::Score]
      # @param _positions [Hash, nil]
      def draw_score(pdf, score, _positions)
        score.staves.each_with_index do |staff, index|
          baseline = pdf.cursor - TOP_PADDING - (index * style.staff_space * 10)
          draw_staff(pdf, staff, baseline)
        end
      end

      # @param pdf [Prawn::Document]
      # @param staff [Clef::Core::Staff]
      # @param baseline [Float]
      def draw_staff(pdf, staff, baseline)
        draw_staff_lines(pdf, baseline)
        cursor = draw_clef(pdf, staff.clef, LEFT_PADDING - 24, baseline)
        cursor += style.staff_space
        cursor = draw_metadata(pdf, staff, cursor, baseline)
        cursor += style.staff_space
        draw_measures(pdf, staff, [cursor, LEFT_PADDING + (style.staff_space * 6)].max, baseline)
      end

      # @param pdf [Prawn::Document]
      # @param baseline [Float]
      def draw_staff_lines(pdf, baseline)
        5.times do |index|
          y = baseline - (index * style.staff_space)
          pdf.stroke_line [LEFT_PADDING, y], [staff_right_bound(pdf), y]
        end
      end

      # @param pdf [Prawn::Document]
      # @param clef [Clef::Core::Clef]
      # @param x [Float]
      # @param baseline [Float]
      def draw_clef(pdf, clef, x, baseline)
        glyph = smufl_enabled? ? glyph_table[:"clef_#{clef.type}"] : fallback_clef_text(clef)
        size = smufl_enabled? ? 16 : 10
        y = smufl_enabled? ? (baseline - style.staff_space) : (baseline + (style.staff_space * 1.5))

        pdf.text_box(glyph, at: [x, y], size: size)
        x + text_width(pdf, glyph, size: size)
      end

      # @param pdf [Prawn::Document]
      # @param staff [Clef::Core::Staff]
      # @param x [Float]
      # @param baseline [Float]
      def draw_metadata(pdf, staff, x, baseline)
        text = metadata_text(staff)
        return x if text.nil?

        size = smufl_enabled? ? 11 : 9
        y = smufl_enabled? ? (baseline - style.staff_space) : (baseline + (style.staff_space * 1.5))
        pdf.text_box(text, at: [x, y], size: size)
        x + text_width(pdf, text, size: size)
      end

      # @param pdf [Prawn::Document]
      # @param staff [Clef::Core::Staff]
      # @param start_x [Float]
      # @param baseline [Float]
      def draw_measures(pdf, staff, start_x, baseline)
        cursor = start_x
        staff.measures.each do |measure|
          cursor = draw_measure(pdf, measure, staff.clef, cursor, baseline)
          draw_barline(pdf, cursor, baseline)
          cursor += style.staff_space * 1.2
        end
      end

      # @param pdf [Prawn::Document]
      # @param measure [Clef::Core::Measure]
      # @param clef [Clef::Core::Clef]
      # @param cursor [Float]
      # @param baseline [Float]
      # @return [Float]
      def draw_measure(pdf, measure, clef, cursor, baseline)
        voice = measure.voices.values.first
        return cursor unless voice

        voice.elements.each do |element|
          draw_element(pdf, element, cursor, baseline, clef)
          cursor += duration_spacing(element)
        end
        cursor
      end

      # @param pdf [Prawn::Document]
      # @param element [Object]
      # @param x [Float]
      # @param baseline [Float]
      # @param clef [Clef::Core::Clef]
      def draw_element(pdf, element, x, baseline, clef)
        case element
        when Clef::Core::Note then draw_note(pdf, element, x, baseline, clef)
        when Clef::Core::Rest then draw_rest(pdf, element, x, baseline)
        when Clef::Core::Chord then draw_chord(pdf, element, x, baseline, clef)
        end
      end

      # @param pdf [Prawn::Document]
      # @param note [Clef::Core::Note]
      # @param x [Float]
      # @param baseline [Float]
      # @param clef [Clef::Core::Clef]
      def draw_note(pdf, note, x, baseline, clef)
        y = pitch_to_y(note.pitch, baseline, clef)
        draw_notehead(pdf, x, y, duration: note.duration)
        draw_accidental(pdf, note.pitch, x, y)
        draw_stem(pdf, note, x, y, clef) if stem_required?(note.duration)
        draw_dot(pdf, note.duration, x, y)
        draw_articulations(pdf, note.articulations, x, y)
      end

      # @param pdf [Prawn::Document]
      # @param rest [Clef::Core::Rest]
      # @param x [Float]
      # @param baseline [Float]
      def draw_rest(pdf, rest, x, baseline)
        glyph = if smufl_enabled?
                  key = rest.duration.base == :whole ? :rest_whole : :rest_quarter
                  glyph_table[key]
                else
                  "r"
                end
        pdf.text_box(glyph, at: [x, baseline - (style.staff_space * 1.5)], size: 14)
      end

      # @param pdf [Prawn::Document]
      # @param chord [Clef::Core::Chord]
      # @param x [Float]
      # @param baseline [Float]
      # @param clef [Clef::Core::Clef]
      def draw_chord(pdf, chord, x, baseline, clef)
        chord.pitches.each { |pitch| draw_notehead(pdf, x, pitch_to_y(pitch, baseline, clef), duration: chord.duration) }
      end

      # @param pdf [Prawn::Document]
      # @param x [Float]
      # @param y [Float]
      # @param duration [Clef::Core::Duration]
      def draw_notehead(pdf, x, y, duration:)
        pdf.fill_color("000000")
        if filled_notehead?(duration)
          pdf.circle([x, y], 3)
          pdf.fill
        else
          pdf.fill_color("FFFFFF")
          pdf.ellipse([x, y], 3.5, 2.5)
          pdf.fill_and_stroke
          pdf.fill_color("000000")
        end
      end

      # @param pdf [Prawn::Document]
      # @param note [Clef::Core::Note]
      # @param x [Float]
      # @param y [Float]
      # @param clef [Clef::Core::Clef]
      def draw_stem(pdf, note, x, y, clef)
        direction = Clef::Layout::Stem.direction(note, clef)
        stem_len = style.staff_space * Clef::Layout::Stem.length(note, clef, direction)
        y2 = direction == :up ? y + stem_len : y - stem_len
        stem_x = direction == :up ? x + 3 : x - 3
        pdf.stroke_line [stem_x, y], [stem_x, y2]
      end

      # @param pdf [Prawn::Document]
      # @param pitch [Clef::Core::Pitch]
      # @param x [Float]
      # @param y [Float]
      def draw_accidental(pdf, pitch, x, y)
        key = accidental_glyph_key(pitch.alteration)
        return unless key

        glyph = smufl_enabled? ? glyph_table[key] : accidental_text(pitch.alteration)
        pdf.text_box(glyph, at: [x - 12, y + 5], size: 9)
      end

      # @param pdf [Prawn::Document]
      # @param duration [Clef::Core::Duration]
      # @param x [Float]
      # @param y [Float]
      def draw_dot(pdf, duration, x, y)
        return if duration.dots.zero?

        duration.dots.times do |index|
          pdf.circle([x + 8 + (index * 3), y], 1)
          pdf.fill
        end
      end

      # @param pdf [Prawn::Document]
      # @param articulations [Array<Symbol>]
      # @param x [Float]
      # @param y [Float]
      def draw_articulations(pdf, articulations, x, y)
        return if articulations.empty?

        text = articulations.join(",")
        pdf.text_box(text, at: [x - 4, y + 12], size: 6)
      end

      # @param pdf [Prawn::Document]
      # @param x [Float]
      # @param baseline [Float]
      def draw_barline(pdf, x, baseline)
        top = baseline + (style.staff_space * 0.5)
        bottom = baseline - (style.staff_space * 4.5)
        pdf.stroke_line [x, top], [x, bottom]
      end

      # @param _pdf [Prawn::Document]
      # @param _slurs [Array]
      def draw_slurs(_pdf, _slurs = []); end

      # @param _pdf [Prawn::Document]
      # @param _ties [Array]
      def draw_ties(_pdf, _ties = []); end

      # @param _pdf [Prawn::Document]
      # @param _beams [Array]
      def draw_beams(_pdf, _beams = []); end

      # @param _pdf [Prawn::Document]
      # @param _lyrics [Array]
      def draw_lyrics(_pdf, _lyrics = []); end

      private

      def prepare_canvas(pdf)
        font_name = font_manager.register_with(pdf)
        pdf.font(font_name)
        @smufl_enabled = (font_name != "Helvetica")
      rescue StandardError
        pdf.font("Helvetica")
        @smufl_enabled = false
      end

      def smufl_enabled?
        @smufl_enabled
      end

      def fallback_clef_text(clef)
        {
          treble: "G",
          bass: "F",
          alto: "C",
          tenor: "C"
        }.fetch(clef.type, clef.type.to_s[0].upcase)
      end

      def metadata_text(staff)
        parts = []
        key_text = key_signature_text(staff.key_signature)
        parts << key_text unless key_text.nil?
        if staff.time_signature
          parts << "#{staff.time_signature.numerator}/#{staff.time_signature.denominator}"
        end
        return nil if parts.empty?

        parts.join(" ")
      end

      def key_signature_text(key_signature)
        return nil if key_signature.nil?

        accidentals = key_signature.accidentals
        count = accidentals[:count].to_i
        return nil if count.zero?

        symbol = accidentals[:type] == :sharp ? "#" : "b"
        "#{count}#{symbol}"
      end

      def text_width(pdf, text, size:)
        return pdf.width_of(text, size: size) if pdf.respond_to?(:width_of)

        text.length * (size * 0.5)
      end

      def filled_notehead?(duration)
        !%i[whole half].include?(duration.base)
      end

      def stem_required?(duration)
        duration.base != :whole
      end

      def pitch_to_y(pitch, baseline, clef)
        reference = clef.reference_pitch
        diatonic = diatonic_step(pitch) - diatonic_step(reference)
        top_line = baseline - (style.staff_space * 4)
        reference_y = top_line + (clef.reference_line * style.staff_space)
        reference_y - (diatonic * (style.staff_space / 2.0))
      end

      def diatonic_step(pitch)
        note_index = Clef::Core::Pitch::VALID_NOTE_NAMES.index(pitch.note_name)
        (pitch.octave * 7) + note_index
      end

      def duration_spacing(element)
        style.min_note_spacing * (element.length.to_f / Rational(1, 4).to_f)
      end

      def accidental_glyph_key(alteration)
        {
          -2 => :accidental_double_flat,
          -1 => :accidental_flat,
          1 => :accidental_sharp,
          2 => :accidental_double_sharp
        }[alteration]
      end

      def accidental_text(alteration)
        {
          -2 => "bb",
          -1 => "b",
          1 => "#",
          2 => "##"
        }.fetch(alteration)
      end

      def staff_right_bound(pdf)
        return pdf.bounds.right if pdf.respond_to?(:bounds)

        LEFT_PADDING + 500
      end
    end
  end
end
