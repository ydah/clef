# frozen_string_literal: true

require "nokogiri"

module Clef
  module Renderer
    class SvgRenderer < Base
      include NotationHelpers

      WIDTH = 1024
      LEFT_PADDING = 60
      RIGHT_PADDING = 60
      STAFF_START_X = 140
      STAFF_TOP = 90

      # @param score [Clef::Core::Score]
      # @param path [String]
      # @param positions [Hash]
      # @param _layout [Hash, nil]
      def render(score, path, positions: nil, layout: nil, **_options)
        height = svg_height(score, layout)
        document = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          xml.svg(xmlns: "http://www.w3.org/2000/svg",
                  width: WIDTH,
                  height: height,
                  viewBox: "0 0 #{WIDTH} #{height}") do
            draw_score(xml, score, positions: positions, layout: layout)
          end
        end
        write_output(path, document.to_xml)
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param score [Clef::Core::Score]
      # @param positions [Hash, nil]
      # @param layout [Hash, nil]
      def draw_score(xml, score, positions: nil, layout: nil)
        return draw_systems(xml, score, layout) if layout&.dig(:systems)&.any?

        draw_header(xml, score)
        staff_index = 0
        score.staff_groups.each do |group|
          group_start = STAFF_TOP + (staff_index * style.staff_gap)
          group.staves.each do |staff|
            baseline = STAFF_TOP + (staff_index * style.staff_gap)
            draw_staff(xml, staff, baseline, positions: positions, layout: layout)
            staff_index += 1
          end
          draw_staff_group(xml, group, group_start, STAFF_TOP + ((staff_index - 1) * style.staff_gap)) if group.staves.length > 1
        end
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param baseline [Float]
      def draw_staff_lines(xml, baseline)
        5.times do |line|
          y = baseline + (line * style.staff_space)
          xml.line(x1: LEFT_PADDING, y1: y, x2: WIDTH - RIGHT_PADDING, y2: y,
                   stroke: "black", "stroke-width": 1, class: "staff-line")
        end
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param element [Object]
      # @param x [Float]
      # @param baseline [Float]
      # @param clef [Clef::Core::Clef]
      def draw_element(xml, element, x, baseline, clef)
        case element
        when Clef::Core::Note then draw_note(xml, element, x, baseline, clef, accidental_state: {}, key_signature: nil)
        when Clef::Core::Rest then draw_rest(xml, element, x, baseline)
        when Clef::Core::Chord then draw_chord(xml, element, x, baseline, clef, accidental_state: {}, key_signature: nil)
        when Clef::Core::Tuplet then draw_tuplet(xml, element, x, baseline, clef, accidental_state: {}, key_signature: nil)
        when Clef::Notation::Dynamic then draw_dynamic(xml, element, x, baseline)
        when Clef::Core::Tempo then draw_tempo_change(xml, element, x, baseline)
        end
      end

      private

      def draw_header(xml, score)
        draw_text(xml, score.title, x: LEFT_PADDING, y: 30, class: "title", "font-size": 18, fill: "black") if score.title
        if score.composer
          draw_text(xml, score.composer, x: WIDTH - RIGHT_PADDING, y: 30, class: "composer",
                    "font-size": 12, fill: "black", "text-anchor": "end")
        end
        return unless score.tempo

        draw_text(xml, tempo_text(score.tempo), x: LEFT_PADDING, y: 52, class: "tempo", "font-size": 11, fill: "black")
      end

      def draw_staff(xml, staff, baseline, positions:, layout:)
        draw_staff_lines(xml, baseline)
        cursor = draw_clef(xml, staff.clef, LEFT_PADDING + 8, baseline)
        cursor = draw_key_signature(xml, staff.key_signature, cursor + style.staff_space, baseline)
        cursor = draw_time_signature(xml, staff.time_signature, cursor + style.staff_space, baseline)
        note_points = draw_measures(xml, staff, [cursor + style.measure_padding, STAFF_START_X].max, baseline, positions, layout)
        draw_lyrics(xml, staff, note_points, baseline)
      end

      def draw_systems(xml, score, layout)
        draw_header(xml, score)
        @system_page_height = svg_page_height_for(score)
        layout[:systems].each do |system|
          score.staff_groups.each do |group|
            baselines = group.staves.map { |staff| svg_system_baseline(system, staff) }
            group.staves.each do |staff|
              draw_staff_system(xml, staff, baselines[group.staves.index(staff)], system, layout)
            end
            draw_staff_group(xml, group, baselines.first, baselines.last) if group.staves.length > 1
          end
          draw_layout_items(xml, layout, system)
        end
      end

      def draw_staff_system(xml, staff, baseline, system, layout)
        draw_staff_lines(xml, baseline)
        cursor = draw_clef(xml, staff.clef, LEFT_PADDING + 8, baseline)
        cursor = draw_key_signature(xml, staff.key_signature, cursor + style.staff_space, baseline)
        cursor = draw_time_signature(xml, staff.time_signature, cursor + style.staff_space, baseline)
        note_points = draw_measures(xml, staff, [cursor + style.measure_padding, STAFF_START_X].max,
                                    baseline, layout[:positions], layout, system: system)
        draw_lyrics(xml, staff, note_points, baseline)
      end

      def draw_staff_group(xml, group, first_baseline, last_baseline)
        x = LEFT_PADDING - 24
        case group.bracket_type
        when :brace
          draw_text(xml, "{", x: x, y: first_baseline + style.staff_space * 3.5,
                    class: "staff-group brace", "font-size": (last_baseline - first_baseline + 50), fill: "black")
        when :bracket
          xml.path(d: "M #{x + 8} #{first_baseline} L #{x} #{first_baseline} L #{x} #{last_baseline + (style.staff_space * 4)} L #{x + 8} #{last_baseline + (style.staff_space * 4)}",
                   fill: "none", stroke: "black", "stroke-width": 2, class: "staff-group bracket")
        end
      end

      def draw_measures(xml, staff, start_x, baseline, positions, layout, system: nil)
        note_points = {}
        measure_start = Clef::Ir::Moment.new(0)
        staff.measures.each do |measure|
          measure_points = draw_measure(xml, measure, staff, start_x, baseline, measure_start, positions, layout, system: system)
          note_points.merge!(measure_points)
          bar_moment = measure_start + measure_length_for(measure)
          if system.nil? || system.include_moment?(bar_moment)
            bar_x = x_for_moment(positions, bar_moment, start_x, position_offset: system&.position_offset)
            draw_barline(xml, bar_x, baseline)
          end
          measure_start += measure_length_for(measure)
        end
        note_points
      end

      def draw_measure(xml, measure, staff, start_x, baseline, measure_start, positions, layout, system: nil)
        note_points = {}
        accidental_state = {}
        measure.voices.each_with_index do |(voice_id, voice), index|
          voice_offset = voice_vertical_offset(index)
          cursor = Clef::Ir::Moment.new(measure_start.value)
          voice.elements.each do |element|
            if system.nil? || system.include_moment?(cursor)
              x = x_for_moment(positions, cursor, start_x, position_offset: system&.position_offset)
              draw_element_with_context(xml, element, x, baseline + voice_offset, staff, measure, accidental_state, note_points)
            end
            cursor += element.length
          end
          draw_beams(xml, layout, staff, measure, voice_id, note_points)
          draw_note_connections(xml, voice.elements, note_points)
        end
        note_points
      end

      def draw_element_with_context(xml, element, x, baseline, staff, measure, accidental_state, note_points)
        case element
        when Clef::Core::Note
          draw_note(xml, element, x, baseline, staff.clef,
                    accidental_state: accidental_state,
                    key_signature: measure.key_signature || staff.key_signature)
          note_points[element.object_id] = [x, pitch_y(element.pitch, baseline, staff.clef)]
        when Clef::Core::Rest
          draw_rest(xml, element, x, baseline)
        when Clef::Core::Chord
          draw_chord(xml, element, x, baseline, staff.clef,
                     accidental_state: accidental_state,
                     key_signature: measure.key_signature || staff.key_signature)
        when Clef::Core::Tuplet
          draw_tuplet(xml, element, x, baseline, staff.clef,
                      accidental_state: accidental_state,
                      key_signature: measure.key_signature || staff.key_signature,
                      note_points: note_points)
        when Clef::Notation::Dynamic
          draw_dynamic(xml, element, x, baseline)
        when Clef::Core::Tempo
          draw_tempo_change(xml, element, x, baseline)
        end
      end

      def draw_note(xml, note, x, baseline, clef, accidental_state:, key_signature:)
        y = pitch_y(note.pitch, baseline, clef)
        draw_ledger_lines(xml, x, y, baseline)
        draw_notehead(xml, x, y, duration: note.duration)
        draw_accidental(xml, note.pitch, x, y, key_signature, accidental_state)
        draw_stem(xml, note, x, y, clef) if stem_required?(note.duration)
        draw_flag(xml, note, x, y, clef) if flag_required?(note.duration)
        draw_dot(xml, note.duration, x, y)
        draw_articulations(xml, note.articulations, x, y)
      end

      def draw_rest(xml, rest, x, baseline)
        return if rest.kind == :invisible || rest.kind == :spacer

        y = rest_y(rest, baseline)
        if rest.duration.base == :whole
          xml.rect(x: x - 4, y: y, width: 8, height: 3, fill: "black", class: "rest rest-whole")
        elsif rest.duration.base == :half
          xml.rect(x: x - 4, y: y - style.staff_space, width: 8, height: 3, fill: "black", class: "rest rest-half")
        else
          draw_text(xml, rest_label(rest.duration), x: x - 4, y: y, fill: "black", "font-size": 14,
                    class: "rest rest-#{rest.duration.base}")
        end
      end

      def draw_dynamic(xml, dynamic, x, baseline)
        draw_text(xml, dynamic_text(dynamic), x: x, y: baseline + (style.staff_space * 6),
                  class: "dynamic", "font-size": 11, fill: "black", "font-style": "italic")
      end

      def draw_tempo_change(xml, tempo, x, baseline)
        draw_text(xml, tempo_text(tempo), x: x, y: baseline - (style.staff_space * 1.5),
                  class: "tempo-change", "font-size": 10, fill: "black")
      end

      def draw_chord(xml, chord, x, baseline, clef, accidental_state:, key_signature:)
        notes = chord_notes(chord)
        offsets = chord_note_offsets(notes)
        ys = []
        notes.each_with_index do |note, index|
          y = pitch_y(note.pitch, baseline, clef)
          ys << y
          note_x = x + offsets[index]
          draw_ledger_lines(xml, note_x, y, baseline)
          draw_notehead(xml, note_x, y, duration: chord.duration)
          draw_accidental(xml, note.pitch, note_x - accidental_offset(index), y, key_signature, accidental_state)
        end
        draw_chord_stem(xml, notes, x, ys, clef) if stem_required?(chord.duration)
        ys.each { |y| draw_dot(xml, chord.duration, x, y) }
      end

      def draw_tuplet(xml, tuplet, x, baseline, clef, accidental_state:, key_signature:, note_points: {})
        cursor = x
        tuplet.elements.each do |element|
          draw_element_with_context(xml, element, cursor, baseline,
                                    Struct.new(:clef, :key_signature).new(clef, key_signature),
                                    Struct.new(:key_signature).new(key_signature),
                                    accidental_state,
                                    note_points)
          cursor += duration_spacing(element) * tuplet.ratio
        end
        draw_text(xml, tuplet.actual.to_s, x: x + ((cursor - x) / 2.0), y: baseline - style.staff_space,
                  class: "tuplet", "font-size": 10, fill: "black", "text-anchor": "middle")
      end

      def draw_notehead(xml, x, y, duration:)
        if filled_notehead?(duration)
          xml.circle(cx: x, cy: y, r: style.notehead_width / 2.0, fill: "black", class: "notehead filled")
        else
          xml.ellipse(cx: x, cy: y, rx: style.notehead_width / 2.0, ry: 2.5,
                      fill: "white", stroke: "black", "stroke-width": 1, class: "notehead hollow")
        end
      end

      def draw_stem(xml, note, x, y, clef)
        direction = Clef::Layout::Stem.direction(note, clef)
        stem_len = style.staff_space * Clef::Layout::Stem.length(note, clef, direction)
        y2 = direction == :up ? y - stem_len : y + stem_len
        stem_x = direction == :up ? x + 3 : x - 3
        xml.line(x1: stem_x, y1: y, x2: stem_x, y2: y2, stroke: "black", "stroke-width": 1, class: "stem")
      end

      def draw_chord_stem(xml, notes, x, ys, clef)
        direction = Clef::Layout::Stem.direction(notes, clef)
        anchor_note = chord_stem_anchor_note(notes, direction)
        anchor_index = notes.index(anchor_note)
        anchor_y = ys[anchor_index]
        stem_len = style.staff_space * chord_stem_length(notes, clef, direction)
        y2 = direction == :up ? anchor_y - stem_len : anchor_y + stem_len
        stem_x = direction == :up ? x + 3 : x - 3
        xml.line(x1: stem_x, y1: anchor_y, x2: stem_x, y2: y2, stroke: "black", "stroke-width": 1, class: "stem")
      end

      def draw_flag(xml, note, x, y, clef)
        direction = Clef::Layout::Stem.direction(note, clef)
        stem_len = style.staff_space * Clef::Layout::Stem.length(note, clef, direction)
        stem_x = direction == :up ? x + 3 : x - 3
        stem_y = direction == :up ? y - stem_len : y + stem_len
        sweep = direction == :up ? 10 : -10
        xml.path(d: "M #{stem_x} #{stem_y} q 12 #{sweep} 4 #{sweep * 2}",
                 fill: "none", stroke: "black", "stroke-width": 1, class: "flag")
      end

      def draw_accidental(xml, pitch, x, y, key_signature, state)
        alteration = accidental_for_pitch(pitch, key_signature, state)
        return if alteration.nil?

        draw_text(xml, accidental_text(alteration), x: x - 12, y: y + 3, fill: "black", "font-size": 9, class: "accidental")
      end

      def draw_dot(xml, duration, x, y)
        return if duration.dots.zero?

        duration.dots.times do |index|
          xml.circle(cx: x + 8 + (index * 3), cy: y, r: 1, fill: "black", class: "dot")
        end
      end

      def draw_articulations(xml, articulations, x, y)
        articulations.each do |articulation|
          case articulation
          when :staccato
            xml.circle(cx: x, cy: y - 12, r: 1.5, fill: "black", class: "articulation staccato")
          when :tenuto
            xml.line(x1: x - 4, y1: y - 12, x2: x + 4, y2: y - 12, stroke: "black",
                     "stroke-width": 1, class: "articulation tenuto")
          when :accent
            draw_text(xml, ">", x: x - 4, y: y - 10, fill: "black", "font-size": 9, class: "articulation accent")
          else
            draw_text(xml, articulation.to_s, x: x - 4, y: y - 12, fill: "black", "font-size": 6, class: "articulation")
          end
        end
      end

      def draw_beams(xml, layout, staff, measure, voice_id, note_points)
        Array(layout&.dig(:beams, staff.id, measure.number, voice_id)).each do |group|
          points = group.filter_map { |note| note_points[note.object_id] }
          next if points.length < 2

          y = points.map(&:last).min - (style.staff_space * 3.5)
          xml.line(x1: points.first.first + 3, y1: y, x2: points.last.first + 3, y2: y,
                   stroke: "black", "stroke-width": style.beam_thickness, class: "beam")
        end
      end

      def draw_note_connections(xml, elements, note_points)
        notes = flatten_elements(elements).select { |element| element.is_a?(Clef::Core::Note) }
        notes.each_with_index do |note, index|
          draw_connection_to_next(xml, note, notes[(index + 1)..], note_points, "tie") if note.tie_state == :start
          draw_connection_to_next(xml, note, notes[(index + 1)..], note_points, "slur") if note.slur_start
        end
      end

      def draw_connection_to_next(xml, note, candidates, note_points, class_name)
        target = class_name == "tie" ? candidates&.find { |candidate| candidate.pitch.enharmonic?(note.pitch) } : candidates&.find(&:slur_end)
        return unless target

        start_point = note_points[note.object_id]
        end_point = note_points[target.object_id]
        return unless start_point && end_point

        lift = class_name == "tie" ? 8 : 14
        path = "M #{start_point[0] + 5} #{start_point[1] - 5} C #{start_point[0] + 18} #{start_point[1] - lift}, " \
               "#{end_point[0] - 18} #{end_point[1] - lift}, #{end_point[0] - 5} #{end_point[1] - 5}"
        xml.path(d: path, fill: "none", stroke: "black", "stroke-width": 1, class: class_name)
      end

      def draw_lyrics(xml, staff, note_points, baseline)
        Array(staff.metadata[:lyrics]).each do |lyric|
          notes = staff.measures.flat_map { |measure| Array(measure.voices[lyric.voice_id]&.elements) }
                      .select { |element| element.is_a?(Clef::Core::Note) }
          lyric.syllables.zip(notes).each do |syllable, note|
            point = note_points[note.object_id]
            next unless syllable && point

            draw_text(xml, syllable, x: point.first, y: baseline + (style.staff_space * 6.5),
                      fill: "black", "font-size": 10, "text-anchor": "middle", class: "lyric")
          end
        end
      end

      def draw_ledger_lines(xml, x, y, baseline)
        top = baseline
        bottom = baseline + (style.staff_space * 4)
        return if y >= top && y <= bottom

        start_line = y < top ? y : bottom + style.staff_space
        end_line = y < top ? top - style.staff_space : y
        current = nearest_staff_line(start_line)
        while current <= end_line
          xml.line(x1: x - 6, y1: current, x2: x + 6, y2: current,
                   stroke: "black", "stroke-width": 1, class: "ledger-line")
          current += style.staff_space
        end
      end

      def draw_clef(xml, clef, x, baseline)
        draw_text(xml, fallback_clef_text(clef), x: x, y: baseline + (style.staff_space * 3.2),
                  class: "clef", "font-size": 22, fill: "black")
        x + 24
      end

      def draw_key_signature(xml, key_signature, x, baseline)
        return x unless key_signature

        accidentals = key_signature.accidentals
        order = accidentals[:type] == :sharp ? NotationHelpers::SHARP_ORDER : NotationHelpers::FLAT_ORDER
        text = accidentals[:type] == :sharp ? "#" : "b"
        order.first(accidentals[:count].to_i).each_with_index do |note_name, index|
          draw_text(xml, text, x: x + (index * 8), y: baseline + key_signature_y(note_name),
                    class: "key-signature", "font-size": 12, fill: "black")
        end
        x + (accidentals[:count].to_i * 8)
      end

      def draw_time_signature(xml, time_signature, x, baseline)
        return x unless time_signature

        draw_text(xml, time_signature.numerator.to_s, x: x, y: baseline + (style.staff_space * 1.6),
                  class: "time-signature numerator", "font-size": 11, fill: "black", "text-anchor": "middle")
        draw_text(xml, time_signature.denominator.to_s, x: x, y: baseline + (style.staff_space * 3.3),
                  class: "time-signature denominator", "font-size": 11, fill: "black", "text-anchor": "middle")
        x + 14
      end

      def draw_barline(xml, x, baseline)
        xml.line(x1: x, y1: baseline, x2: x, y2: baseline + (style.staff_space * 4),
                 stroke: "black", "stroke-width": 1, class: "barline")
      end

      def pitch_y(pitch, baseline, clef)
        calculate_pitch_y(pitch, baseline, clef, vertical_axis: drawing_context.vertical_axis)
      end

      def draw_text(xml, content, **attributes)
        node = Nokogiri::XML::Node.new("text", xml.doc)
        attributes.each { |key, value| node[key.to_s] = value.to_s }
        node.content = content.to_s
        xml.parent << node
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

        index.odd? ? style.staff_space * 0.8 : -style.staff_space * 0.8
      end

      def rest_y(rest, baseline)
        offset = {
          whole: 2.8,
          half: 2.8,
          quarter: 2.3,
          eighth: 2.0,
          sixteenth: 2.0
        }.fetch(rest.duration.base, 2.0)
        baseline + (style.staff_space * offset)
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

      def key_signature_y(note_name)
        {
          f: style.staff_space * 0.9,
          c: style.staff_space * 2.4,
          g: style.staff_space * 0.5,
          d: style.staff_space * 2.0,
          a: style.staff_space * 3.4,
          e: style.staff_space * 1.5,
          b: style.staff_space * 3.0
        }.fetch(note_name)
      end

      def chord_note_offsets(notes)
        notes.each_with_index.map do |note, index|
          previous = notes[index - 1]
          previous && (diatonic_step(note.pitch) - diatonic_step(previous.pitch)).abs == 1 ? 6 : 0
        end
      end

      def accidental_offset(index)
        index * 4
      end

      def nearest_staff_line(value)
        (value / style.staff_space).floor * style.staff_space
      end

      def tempo_text(tempo)
        "#{tempo.beat_unit.to_lilypond} = #{tempo.bpm}"
      end

      def svg_height(score, layout)
        systems = Array(layout&.dig(:systems))
        return [STAFF_TOP + (score.staves.length * style.staff_gap) + style.staff_gap, 180].max if systems.empty?

        page_count = systems.map(&:page_index).max.to_i + 1
        [STAFF_TOP + (page_count * svg_page_height_for(score)) + style.system_gap, 180].max
      end

      def svg_page_height_for(score)
        STAFF_TOP + (score.staves.length * style.staff_gap) + (style.system_gap * 2)
      end

      def svg_system_baseline(system, staff)
        STAFF_TOP + (system.page_index * @system_page_height.to_f) + system.line_top + system.staff_offset(staff.id)
      end

      def draw_layout_items(xml, layout, system)
        Array(layout[:items]).each do |item|
          next unless item.type == :text
          next unless system.include_moment?(item.moment)

          x = x_for_moment(layout[:positions], item.moment, STAFF_START_X, position_offset: system.position_offset)
          y = STAFF_TOP + (system.page_index * @system_page_height.to_f) + system.line_top - style.staff_space
          draw_text(xml, item.payload.fetch(:text), x: x, y: y, class: "layout-item", "font-size": 10, fill: "black")
        end
      end

      def drawing_context
        @drawing_context ||= Clef::Renderer::DrawingContext.svg
      end

      def write_output(target, content)
        return target.write(content) if target.respond_to?(:write)

        ensure_parent_directory!(target)
        File.write(target, content)
      end

      def ensure_parent_directory!(path)
        parent = File.dirname(path.to_s)
        return if parent.nil? || parent == "." || Dir.exist?(parent)

        raise ArgumentError, "output directory does not exist: #{parent}"
      end
    end
  end
end
