# frozen_string_literal: true

require "prawn"

module Clef
  module Renderer
    class PdfRenderer < Base
      include NotationHelpers

      LEFT_PADDING = 80
      TOP_PADDING = 56
      STAFF_START_X = 160

      # @param score [Clef::Core::Score]
      # @param path [String]
      # @param positions [Hash]
      # @param layout [Hash, nil]
      def render(score, path, positions: nil, layout: nil, **_options)
        return render_to_io(score, path, positions: positions, layout: layout) if path.respond_to?(:write)

        ensure_parent_directory!(path)
        Prawn::Document.generate(path, page_size: style.page_size, margin: style.margin) do |pdf|
          prepare_canvas(pdf)
          draw_score(pdf, score, positions, layout: layout)
        end
      end

      # @param pdf [Prawn::Document]
      # @param score [Clef::Core::Score]
      # @param positions [Hash, nil]
      # @param layout [Hash, nil]
      def draw_score(pdf, score, positions, layout: nil)
        return draw_systems(pdf, score, layout) if layout&.dig(:systems)&.any?

        draw_header(pdf, score)
        staff_index = 0
        score.staff_groups.each do |group|
          group_start = pdf.cursor - TOP_PADDING - (staff_index * style.staff_gap)
          group.staves.each do |staff|
            baseline = pdf.cursor - TOP_PADDING - (staff_index * style.staff_gap)
            draw_staff(pdf, staff, baseline, positions: positions, layout: layout)
            staff_index += 1
          end
          draw_staff_group(pdf, group, group_start, staff_index - 1) if group.staves.length > 1
        end
      end

      # @param pdf [Prawn::Document]
      # @param staff [Clef::Core::Staff]
      # @param baseline [Float]
      # @param positions [Hash, nil]
      # @param layout [Hash, nil]
      def draw_staff(pdf, staff, baseline, positions: nil, layout: nil)
        draw_staff_lines(pdf, baseline)
        cursor = draw_clef(pdf, staff.clef, LEFT_PADDING - 24, baseline)
        cursor = draw_key_signature(pdf, staff.key_signature, cursor + style.staff_space, baseline)
        cursor = draw_time_signature(pdf, staff.time_signature, cursor + style.staff_space, baseline)
        note_points = draw_measures(pdf, staff, [cursor + style.measure_padding, STAFF_START_X].max, baseline, positions, layout)
        draw_lyrics(pdf, staff, note_points, baseline)
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
        glyph ||= fallback_clef_text(clef)
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
        cursor = draw_key_signature(pdf, staff.key_signature, x, baseline)
        draw_time_signature(pdf, staff.time_signature, cursor + style.staff_space, baseline)
      end

      # @param pdf [Prawn::Document]
      # @param staff [Clef::Core::Staff]
      # @param start_x [Float]
      # @param baseline [Float]
      # @param positions [Hash, nil]
      # @param layout [Hash, nil]
      def draw_measures(pdf, staff, start_x, baseline, positions = nil, layout = nil, system: nil)
        note_points = {}
        measure_start = Clef::Ir::Moment.new(0)
        staff.measures.each do |measure|
          note_points.merge!(draw_measure(pdf, measure, staff, start_x, baseline, measure_start, positions, layout, system: system))
          bar_moment = measure_start + measure_length_for(measure)
          if system.nil? || system.include_moment?(bar_moment)
            bar_x = x_for_moment(positions, bar_moment, start_x, position_offset: system&.position_offset)
            draw_barline(pdf, bar_x, baseline)
          end
          measure_start += measure_length_for(measure)
        end
        note_points
      end

      # @param pdf [Prawn::Document]
      # @param measure [Clef::Core::Measure]
      # @param staff [Clef::Core::Staff]
      # @param start_x [Float]
      # @param baseline [Float]
      # @param measure_start [Clef::Ir::Moment]
      # @param positions [Hash, nil]
      # @param layout [Hash, nil]
      # @return [Hash]
      def draw_measure(pdf, measure, staff, start_x, baseline, measure_start = Clef::Ir::Moment.new(0), positions = nil, layout = nil, system: nil)
        note_points = {}
        accidental_state = {}
        measure.voices.each_with_index do |(voice_id, voice), index|
          cursor = Clef::Ir::Moment.new(measure_start.value)
          voice_baseline = baseline + voice_vertical_offset(index)
          voice.elements.each do |element|
            if system.nil? || system.include_moment?(cursor)
              x = x_for_moment(positions, cursor, start_x, position_offset: system&.position_offset)
              draw_element_with_context(pdf, element, x, voice_baseline, staff, measure, accidental_state, note_points)
            end
            cursor += element.length
          end
          draw_beams(pdf, layout, staff, measure, voice_id, note_points)
          draw_note_connections(pdf, voice.elements, note_points)
        end
        note_points
      end

      # @param pdf [Prawn::Document]
      # @param element [Object]
      # @param x [Float]
      # @param baseline [Float]
      # @param clef [Clef::Core::Clef]
      def draw_element(pdf, element, x, baseline, clef)
        case element
        when Clef::Core::Note then draw_note(pdf, element, x, baseline, clef, accidental_state: {}, key_signature: nil)
        when Clef::Core::Rest then draw_rest(pdf, element, x, baseline)
        when Clef::Core::Chord then draw_chord(pdf, element, x, baseline, clef, accidental_state: {}, key_signature: nil)
        when Clef::Core::Tuplet then draw_tuplet(pdf, element, x, baseline, clef, accidental_state: {}, key_signature: nil)
        when Clef::Notation::Dynamic then draw_dynamic(pdf, element, x, baseline)
        when Clef::Core::Tempo then draw_tempo_change(pdf, element, x, baseline)
        end
      end

      # @param pdf [Prawn::Document]
      # @param note [Clef::Core::Note]
      # @param x [Float]
      # @param baseline [Float]
      # @param clef [Clef::Core::Clef]
      def draw_note(pdf, note, x, baseline, clef, accidental_state:, key_signature:)
        y = pitch_to_y(note.pitch, baseline, clef)
        draw_ledger_lines(pdf, x, y, baseline)
        draw_notehead(pdf, x, y, duration: note.duration)
        draw_accidental(pdf, note.pitch, x, y, key_signature, accidental_state)
        draw_stem(pdf, note, x, y, clef) if stem_required?(note.duration)
        draw_flag(pdf, note, x, y, clef) if flag_required?(note.duration)
        draw_dot(pdf, note.duration, x, y)
        draw_articulations(pdf, note.articulations, x, y)
      end

      # @param pdf [Prawn::Document]
      # @param rest [Clef::Core::Rest]
      # @param x [Float]
      # @param baseline [Float]
      def draw_rest(pdf, rest, x, baseline)
        return if rest.kind == :invisible || rest.kind == :spacer

        glyph = if smufl_enabled?
          glyph_table[:"rest_#{rest.duration.base}"] || glyph_table[:rest_quarter]
        else
          rest_label(rest.duration)
        end
        pdf.text_box(glyph, at: [x, rest_y(rest, baseline)], size: 14)
      end

      # @param pdf [Prawn::Document]
      # @param chord [Clef::Core::Chord]
      # @param x [Float]
      # @param baseline [Float]
      # @param clef [Clef::Core::Clef]
      def draw_chord(pdf, chord, x, baseline, clef, accidental_state:, key_signature:)
        notes = chord_notes(chord)
        offsets = chord_note_offsets(notes)
        ys = []
        notes.each_with_index do |note, index|
          y = pitch_to_y(note.pitch, baseline, clef)
          ys << y
          note_x = x + offsets[index]
          draw_ledger_lines(pdf, note_x, y, baseline)
          draw_notehead(pdf, note_x, y, duration: chord.duration)
          draw_accidental(pdf, note.pitch, note_x - accidental_offset(index), y, key_signature, accidental_state)
        end
        draw_chord_stem(pdf, notes, x, ys, clef) if stem_required?(chord.duration)
        ys.each { |y| draw_dot(pdf, chord.duration, x, y) }
      end

      # @param pdf [Prawn::Document]
      # @param tuplet [Clef::Core::Tuplet]
      # @param x [Float]
      # @param baseline [Float]
      # @param clef [Clef::Core::Clef]
      def draw_tuplet(pdf, tuplet, x, baseline, clef, accidental_state:, key_signature:, note_points: {})
        cursor = x
        staff_context = Struct.new(:clef, :key_signature).new(clef, key_signature)
        measure_context = Struct.new(:key_signature).new(key_signature)
        tuplet.elements.each do |element|
          draw_element_with_context(pdf, element, cursor, baseline, staff_context, measure_context, accidental_state, note_points)
          cursor += duration_spacing(element) * tuplet.ratio
        end
        pdf.text_box(tuplet.actual.to_s, at: [x + ((cursor - x) / 2.0), baseline + style.staff_space], size: 8)
      end

      # @param pdf [Prawn::Document]
      # @param x [Float]
      # @param y [Float]
      # @param duration [Clef::Core::Duration]
      def draw_notehead(pdf, x, y, duration:)
        pdf.fill_color("000000")
        if filled_notehead?(duration)
          pdf.circle([x, y], style.notehead_width / 2.0)
          pdf.fill
        else
          pdf.fill_color("FFFFFF")
          pdf.ellipse([x, y], style.notehead_width / 2.0, 2.5)
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
        y2 = (direction == :up) ? y + stem_len : y - stem_len
        stem_x = (direction == :up) ? x + 3 : x - 3
        pdf.stroke_line [stem_x, y], [stem_x, y2]
      end

      # @param pdf [Prawn::Document]
      # @param notes [Array<Clef::Core::Note>]
      # @param x [Float]
      # @param ys [Array<Float>]
      # @param clef [Clef::Core::Clef]
      def draw_chord_stem(pdf, notes, x, ys, clef)
        direction = Clef::Layout::Stem.direction(notes, clef)
        anchor_note = chord_stem_anchor_note(notes, direction)
        anchor_index = notes.index(anchor_note)
        anchor_y = ys[anchor_index]
        stem_len = style.staff_space * chord_stem_length(notes, clef, direction)
        y2 = (direction == :up) ? anchor_y + stem_len : anchor_y - stem_len
        stem_x = (direction == :up) ? x + 3 : x - 3
        pdf.stroke_line [stem_x, anchor_y], [stem_x, y2]
      end

      # @param pdf [Prawn::Document]
      # @param pitch [Clef::Core::Pitch]
      # @param x [Float]
      # @param y [Float]
      # @param key_signature [Clef::Core::KeySignature, nil]
      # @param state [Hash]
      def draw_accidental(pdf, pitch, x, y, key_signature, state)
        alteration = accidental_for_pitch(pitch, key_signature, state)
        return if alteration.nil?

        key = accidental_glyph_key(alteration)
        glyph = smufl_enabled? ? glyph_table[key] : accidental_text(alteration)
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
        articulations.each do |articulation|
          case articulation
          when :staccato
            pdf.circle([x, y + 12], 1.5)
            pdf.fill
          when :tenuto
            pdf.stroke_line [x - 4, y + 12], [x + 4, y + 12]
          when :accent
            pdf.text_box(">", at: [x - 4, y + 14], size: 9)
          else
            pdf.text_box(articulation.to_s, at: [x - 4, y + 12], size: 6)
          end
        end
      end

      # @param pdf [Prawn::Document]
      # @param x [Float]
      # @param baseline [Float]
      def draw_barline(pdf, x, baseline)
        top = baseline + (style.staff_space * 0.5)
        bottom = baseline - (style.staff_space * 4.5)
        pdf.stroke_line [x, top], [x, bottom]
      end

      # Compatibility extension points; concrete drawing now happens during measure rendering.
      def draw_slurs(_pdf, _slurs = [])
      end

      def draw_ties(_pdf, _ties = [])
      end

      private

      def draw_systems(pdf, score, layout)
        draw_header(pdf, score)
        current_page = 0
        layout[:systems].each_with_index do |system, index|
          if index.positive? && system.page_index != current_page
            pdf.start_new_page
            current_page = system.page_index
            draw_header(pdf, score)
          end
          score.staff_groups.each do |group|
            baselines = group.staves.map { |staff| pdf_system_baseline(pdf, system, staff) }
            group.staves.each do |staff|
              draw_staff_system(pdf, staff, baselines[group.staves.index(staff)], system, layout)
            end
            draw_staff_group_at(pdf, group, baselines.first, baselines.last) if group.staves.length > 1
          end
          draw_layout_items(pdf, layout, system)
        end
      end

      def draw_staff_system(pdf, staff, baseline, system, layout)
        draw_staff_lines(pdf, baseline)
        cursor = draw_clef(pdf, staff.clef, LEFT_PADDING - 24, baseline)
        cursor = draw_key_signature(pdf, staff.key_signature, cursor + style.staff_space, baseline)
        cursor = draw_time_signature(pdf, staff.time_signature, cursor + style.staff_space, baseline)
        note_points = draw_measures(pdf, staff, [cursor + style.measure_padding, STAFF_START_X].max,
          baseline, layout[:positions], layout, system: system)
        draw_lyrics(pdf, staff, note_points, baseline)
      end

      def pdf_system_baseline(pdf, system, staff)
        pdf.bounds.top - TOP_PADDING - system.line_top - system.staff_offset(staff.id)
      end

      def draw_header(pdf, score)
        pdf.text_box(score.title, at: [LEFT_PADDING, pdf.cursor + 18], size: 16) if score.title
        if score.composer
          pdf.text_box(score.composer, at: [pdf.bounds.right - 180, pdf.cursor + 18], width: 180, size: 10, align: :right)
        end
        return unless score.tempo

        pdf.text_box(tempo_text(score.tempo), at: [LEFT_PADDING, pdf.cursor], size: 9)
      end

      def draw_staff_group(pdf, group, first_baseline, last_staff_index)
        last_baseline = pdf.cursor - TOP_PADDING - (last_staff_index * style.staff_gap)
        draw_staff_group_at(pdf, group, first_baseline, last_baseline)
      end

      def draw_staff_group_at(pdf, group, first_baseline, last_baseline)
        x = LEFT_PADDING - 36
        case group.bracket_type
        when :brace
          pdf.text_box("{", at: [x, first_baseline + style.staff_space], size: [last_baseline - first_baseline, 28].max.abs)
        when :bracket
          pdf.stroke_line [x, first_baseline + style.staff_space * 0.5], [x, last_baseline - style.staff_space * 4.5]
          pdf.stroke_line [x, first_baseline + style.staff_space * 0.5], [x + 8, first_baseline + style.staff_space * 0.5]
          pdf.stroke_line [x, last_baseline - style.staff_space * 4.5], [x + 8, last_baseline - style.staff_space * 4.5]
        end
      end

      def draw_element_with_context(pdf, element, x, baseline, staff, measure, accidental_state, note_points)
        case element
        when Clef::Core::Note
          draw_note(pdf, element, x, baseline, staff.clef,
            accidental_state: accidental_state,
            key_signature: measure.key_signature || staff.key_signature)
          note_points[element.object_id] = [x, pitch_to_y(element.pitch, baseline, staff.clef)]
        when Clef::Core::Rest
          draw_rest(pdf, element, x, baseline)
        when Clef::Core::Chord
          draw_chord(pdf, element, x, baseline, staff.clef,
            accidental_state: accidental_state,
            key_signature: measure.key_signature || staff.key_signature)
        when Clef::Core::Tuplet
          draw_tuplet(pdf, element, x, baseline, staff.clef,
            accidental_state: accidental_state,
            key_signature: measure.key_signature || staff.key_signature,
            note_points: note_points)
        when Clef::Notation::Dynamic
          draw_dynamic(pdf, element, x, baseline)
        when Clef::Core::Tempo
          draw_tempo_change(pdf, element, x, baseline)
        end
      end

      def draw_dynamic(pdf, dynamic, x, baseline)
        pdf.text_box(dynamic_text(dynamic), at: [x, baseline - (style.staff_space * 6)], size: 9)
      end

      def draw_tempo_change(pdf, tempo, x, baseline)
        pdf.text_box(tempo_text(tempo), at: [x, baseline + (style.staff_space * 1.5)], size: 8)
      end

      def draw_flag(pdf, note, x, y, clef)
        direction = Clef::Layout::Stem.direction(note, clef)
        stem_len = style.staff_space * Clef::Layout::Stem.length(note, clef, direction)
        stem_x = (direction == :up) ? x + 3 : x - 3
        stem_y = (direction == :up) ? y + stem_len : y - stem_len
        sweep = (direction == :up) ? -8 : 8
        pdf.stroke_line [stem_x, stem_y], [stem_x + 8, stem_y + sweep]
      end

      def draw_beams(pdf, layout, staff, measure, voice_id, note_points)
        Array(layout&.dig(:beams, staff.id, measure.number, voice_id)).each do |group|
          points = group.filter_map { |note| note_points[note.object_id] }
          next if points.length < 2

          y = points.map(&:last).max + (style.staff_space * 3.5)
          previous_width = pdf.line_width if pdf.respond_to?(:line_width)
          pdf.line_width = style.beam_thickness if pdf.respond_to?(:line_width=)
          pdf.stroke_line [points.first.first + 3, y], [points.last.first + 3, y]
          pdf.line_width = previous_width if previous_width && pdf.respond_to?(:line_width=)
        end
      end

      def draw_note_connections(pdf, elements, note_points)
        notes = flatten_elements(elements).select { |element| element.is_a?(Clef::Core::Note) }
        notes.each_with_index do |note, index|
          draw_connection_to_next(pdf, note, notes[(index + 1)..], note_points, :tie) if note.tie_state == :start
          draw_connection_to_next(pdf, note, notes[(index + 1)..], note_points, :slur) if note.slur_start
        end
      end

      def draw_connection_to_next(pdf, note, candidates, note_points, kind)
        target = (kind == :tie) ? candidates&.find { |candidate| candidate.pitch.enharmonic?(note.pitch) } : candidates&.find(&:slur_end)
        return unless target

        start_point = note_points[note.object_id]
        end_point = note_points[target.object_id]
        return unless start_point && end_point

        lift = (kind == :tie) ? 8 : 14
        if pdf.respond_to?(:stroke_curve)
          pdf.stroke_curve [start_point[0] + 5, start_point[1] + 5],
            [end_point[0] - 5, end_point[1] + 5],
            bounds: [[start_point[0] + 18, start_point[1] + lift],
              [end_point[0] - 18, end_point[1] + lift]]
        else
          pdf.stroke_line [start_point[0] + 5, start_point[1] + 5], [end_point[0] - 5, end_point[1] + 5]
        end
      end

      def draw_lyrics(pdf, staff, note_points, baseline)
        Array(staff.metadata[:lyrics]).each do |lyric|
          notes = staff.measures.flat_map { |measure| Array(measure.voices[lyric.voice_id]&.elements) }
            .select { |element| element.is_a?(Clef::Core::Note) }
          lyric.syllables.zip(notes).each do |syllable, note|
            point = note_points[note.object_id]
            next unless syllable && point

            pdf.text_box(syllable, at: [point.first - 10, baseline - (style.staff_space * 6)], size: 8, width: 24, align: :center)
          end
        end
      end

      def draw_ledger_lines(pdf, x, y, baseline)
        top = baseline
        bottom = baseline - (style.staff_space * 4)
        return if y.between?(bottom, top)

        current = (y > top) ? top + style.staff_space : bottom - style.staff_space
        while (y > top) ? current <= y : current >= y
          pdf.stroke_line [x - 6, current], [x + 6, current]
          current += (y > top) ? style.staff_space : -style.staff_space
        end
      end

      def draw_key_signature(pdf, key_signature, x, baseline)
        return x unless key_signature

        accidentals = key_signature.accidentals
        order = (accidentals[:type] == :sharp) ? NotationHelpers::SHARP_ORDER : NotationHelpers::FLAT_ORDER
        text = (accidentals[:type] == :sharp) ? "#" : "b"
        order.first(accidentals[:count].to_i).each_with_index do |note_name, index|
          y = baseline - key_signature_y(note_name)
          pdf.text_box(text, at: [x + (index * 8), y], size: 10)
        end
        x + (accidentals[:count].to_i * 8)
      end

      def draw_time_signature(pdf, time_signature, x, baseline)
        return x unless time_signature

        pdf.text_box(time_signature.numerator.to_s, at: [x, baseline - (style.staff_space * 0.9)], size: 10, align: :center, width: 10)
        pdf.text_box(time_signature.denominator.to_s, at: [x, baseline - (style.staff_space * 2.7)], size: 10, align: :center, width: 10)
        x + 14
      end

      def prepare_canvas(pdf)
        font_name = font_manager.register_with(pdf)
        pdf.font(font_name)
        @smufl_enabled = (font_name != "Helvetica")
      rescue
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
          tenor: "C",
          percussion: "||",
          tab: "TAB"
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

        symbol = (accidentals[:type] == :sharp) ? "#" : "b"
        "#{count}#{symbol}"
      end

      def text_width(pdf, text, size:)
        return pdf.width_of(text, size: size) if pdf.respond_to?(:width_of)

        text.length * (size * 0.5)
      end

      def pitch_to_y(pitch, baseline, clef)
        calculate_pitch_y(pitch, baseline, clef, vertical_axis: drawing_context.vertical_axis)
      end

      def staff_right_bound(pdf)
        return pdf.bounds.right if pdf.respond_to?(:bounds)

        LEFT_PADDING + 500
      end

      def x_for_moment(positions, moment, start_x, position_offset: 0.0)
        return start_x unless positions

        start_x + positions.fetch(moment, position_offset.to_f) - position_offset.to_f
      end

      def measure_length_for(measure)
        return measure.time_signature.measure_length if measure.time_signature

        measure.voices.values.map(&:total_length).max || Rational(0, 1)
      end

      def voice_vertical_offset(index)
        return 0 if index.zero?

        index.odd? ? -(style.staff_space * 0.8) : style.staff_space * 0.8
      end

      def rest_y(rest, baseline)
        offset = {
          whole: 2.0,
          half: 2.2,
          quarter: 1.6,
          eighth: 1.4,
          sixteenth: 1.4
        }.fetch(rest.duration.base, 1.4)
        baseline - (style.staff_space * offset)
      end

      def key_signature_y(note_name)
        {
          f: style.staff_space * 0.5,
          c: style.staff_space * 2.0,
          g: style.staff_space * 0.1,
          d: style.staff_space * 1.6,
          a: style.staff_space * 3.0,
          e: style.staff_space * 1.1,
          b: style.staff_space * 2.6
        }.fetch(note_name)
      end

      def chord_note_offsets(notes)
        notes.each_with_index.map do |note, index|
          previous = notes[index - 1]
          (previous && (diatonic_step(note.pitch) - diatonic_step(previous.pitch)).abs == 1) ? 6 : 0
        end
      end

      def accidental_offset(index)
        index * 4
      end

      def tempo_text(tempo)
        "#{tempo.beat_unit.to_lilypond} = #{tempo.bpm}"
      end

      def draw_layout_items(pdf, layout, system)
        Array(layout[:items]).each do |item|
          next unless item.type == :text
          next unless system.include_moment?(item.moment)

          x = x_for_moment(layout[:positions], item.moment, STAFF_START_X, position_offset: system.position_offset)
          y = pdf.bounds.top - TOP_PADDING - system.line_top + style.staff_space
          pdf.text_box(item.payload.fetch(:text), at: [x, y], size: 8)
        end
      end

      def drawing_context
        @drawing_context ||= Clef::Renderer::DrawingContext.pdf
      end

      def render_to_io(score, io, positions:, layout:)
        pdf = Prawn::Document.new(page_size: style.page_size, margin: style.margin)
        prepare_canvas(pdf)
        draw_score(pdf, score, positions, layout: layout)
        io.write(pdf.render)
      end

      def ensure_parent_directory!(path)
        parent = File.dirname(path.to_s)
        return if parent.nil? || parent == "." || Dir.exist?(parent)

        raise ArgumentError, "output directory does not exist: #{parent}"
      end
    end
  end
end
