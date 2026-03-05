# frozen_string_literal: true

require "nokogiri"

module Clef
  module Renderer
    class SvgRenderer < Base
      include NotationHelpers

      WIDTH = 1024
      HEIGHT = 512

      # @param score [Clef::Core::Score]
      # @param path [String]
      # @param _positions [Hash]
      def render(score, path, _positions: nil, **_options)
        document = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          xml.svg(xmlns: "http://www.w3.org/2000/svg", width: WIDTH, height: HEIGHT) do
            draw_score(xml, score)
          end
        end
        File.write(path, document.to_xml)
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param score [Clef::Core::Score]
      def draw_score(xml, score)
        score.staves.each_with_index do |staff, index|
          baseline = 80 + (index * style.staff_space * 9)
          draw_staff_lines(xml, baseline)
          draw_notes(xml, staff, baseline)
        end
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param baseline [Float]
      def draw_staff_lines(xml, baseline)
        5.times do |line|
          y = baseline + (line * style.staff_space)
          xml.line(x1: 60, y1: y, x2: WIDTH - 60, y2: y, stroke: "black", "stroke-width": 1)
        end
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param staff [Clef::Core::Staff]
      # @param baseline [Float]
      def draw_notes(xml, staff, baseline)
        x = 140
        staff.measures.each do |measure|
          voice = measure.voices.values.first
          next unless voice

          voice.elements.each do |element|
            draw_element(xml, element, x, baseline, staff.clef)
            x += duration_spacing(element)
          end
          x += 16
        end
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param element [Object]
      # @param x [Float]
      # @param baseline [Float]
      # @param clef [Clef::Core::Clef]
      def draw_element(xml, element, x, baseline, clef)
        case element
        when Clef::Core::Note then draw_note(xml, element, x, baseline, clef)
        when Clef::Core::Rest then draw_rest(xml, element, x, baseline)
        when Clef::Core::Chord then draw_chord(xml, element, x, baseline, clef)
        end
      end

      private

      # @param xml [Nokogiri::XML::Builder]
      # @param note [Clef::Core::Note]
      # @param x [Float]
      # @param baseline [Float]
      # @param clef [Clef::Core::Clef]
      def draw_note(xml, note, x, baseline, clef)
        y = pitch_y(note.pitch, baseline, clef)
        draw_notehead(xml, x, y, duration: note.duration)
        draw_accidental(xml, note.pitch, x, y)
        draw_stem(xml, note, x, y, clef) if stem_required?(note.duration)
        draw_dot(xml, note.duration, x, y)
        draw_articulations(xml, note.articulations, x, y)
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param rest [Clef::Core::Rest]
      # @param x [Float]
      # @param baseline [Float]
      def draw_rest(xml, rest, x, baseline)
        if rest.duration.base == :whole
          xml.rect(x: x - 4, y: baseline + (style.staff_space * 2.8), width: 8, height: 3, fill: "black")
        else
          draw_text(xml, "r", x: x - 4, y: baseline + (style.staff_space * 2.1), fill: "black", "font-size": 14)
        end
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param chord [Clef::Core::Chord]
      # @param x [Float]
      # @param baseline [Float]
      # @param clef [Clef::Core::Clef]
      def draw_chord(xml, chord, x, baseline, clef)
        notes = chord_notes(chord)
        ys = []
        notes.each do |note|
          y = pitch_y(note.pitch, baseline, clef)
          ys << y
          draw_notehead(xml, x, y, duration: chord.duration)
          draw_accidental(xml, note.pitch, x, y)
        end
        draw_chord_stem(xml, notes, x, ys, clef) if stem_required?(chord.duration)
        draw_dot(xml, chord.duration, x, ys.sum / ys.length.to_f)
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param x [Float]
      # @param y [Float]
      # @param duration [Clef::Core::Duration]
      def draw_notehead(xml, x, y, duration:)
        if filled_notehead?(duration)
          xml.circle(cx: x, cy: y, r: 3, fill: "black")
        else
          xml.ellipse(cx: x, cy: y, rx: 3.5, ry: 2.5, fill: "white", stroke: "black", "stroke-width": 1)
        end
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param note [Clef::Core::Note]
      # @param x [Float]
      # @param y [Float]
      # @param clef [Clef::Core::Clef]
      def draw_stem(xml, note, x, y, clef)
        direction = Clef::Layout::Stem.direction(note, clef)
        stem_len = style.staff_space * Clef::Layout::Stem.length(note, clef, direction)
        y2 = direction == :up ? y - stem_len : y + stem_len
        stem_x = direction == :up ? x + 3 : x - 3
        xml.line(x1: stem_x, y1: y, x2: stem_x, y2: y2, stroke: "black", "stroke-width": 1)
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param notes [Array<Clef::Core::Note>]
      # @param x [Float]
      # @param ys [Array<Float>]
      # @param clef [Clef::Core::Clef]
      def draw_chord_stem(xml, notes, x, ys, clef)
        direction = Clef::Layout::Stem.direction(notes, clef)
        anchor_note = chord_stem_anchor_note(notes, direction)
        anchor_index = notes.index(anchor_note)
        anchor_y = ys[anchor_index]
        stem_len = style.staff_space * chord_stem_length(notes, clef, direction)
        y2 = direction == :up ? anchor_y - stem_len : anchor_y + stem_len
        stem_x = direction == :up ? x + 3 : x - 3
        xml.line(x1: stem_x, y1: anchor_y, x2: stem_x, y2: y2, stroke: "black", "stroke-width": 1)
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param pitch [Clef::Core::Pitch]
      # @param x [Float]
      # @param y [Float]
      def draw_accidental(xml, pitch, x, y)
        key = accidental_glyph_key(pitch.alteration)
        return unless key

        draw_text(xml, accidental_text(pitch.alteration), x: x - 12, y: y + 3, fill: "black", "font-size": 9)
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param duration [Clef::Core::Duration]
      # @param x [Float]
      # @param y [Float]
      def draw_dot(xml, duration, x, y)
        return if duration.dots.zero?

        duration.dots.times do |index|
          xml.circle(cx: x + 8 + (index * 3), cy: y, r: 1, fill: "black")
        end
      end

      # @param xml [Nokogiri::XML::Builder]
      # @param articulations [Array<Symbol>]
      # @param x [Float]
      # @param y [Float]
      def draw_articulations(xml, articulations, x, y)
        return if articulations.empty?

        draw_text(xml, articulations.join(","), x: x - 4, y: y - 12, fill: "black", "font-size": 6)
      end

      def pitch_y(pitch, baseline, clef)
        calculate_pitch_y(pitch, baseline, clef, vertical_axis: -1)
      end

      def draw_text(xml, content, **attributes)
        node = Nokogiri::XML::Node.new("text", xml.doc)
        attributes.each { |key, value| node[key.to_s] = value.to_s }
        node.content = content.to_s
        xml.parent << node
      end
    end
  end
end
