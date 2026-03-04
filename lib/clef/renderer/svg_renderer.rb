# frozen_string_literal: true

require "nokogiri"

module Clef
  module Renderer
    class SvgRenderer < Base
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
            x += style.min_note_spacing * (element.length.to_f / Rational(1, 4).to_f)
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
        when Clef::Core::Note
          y = pitch_y(element.pitch, baseline, clef)
          xml.circle(cx: x, cy: y, r: 3, fill: "black")
        when Clef::Core::Rest
          xml.rect(x: x - 2, y: baseline + (style.staff_space * 0.8), width: 5, height: 4, fill: "black")
        when Clef::Core::Chord
          element.pitches.each { |pitch| xml.circle(cx: x, cy: pitch_y(pitch, baseline, clef), r: 3, fill: "black") }
        end
      end

      private

      def pitch_y(pitch, baseline, clef)
        reference = clef.reference_pitch
        note_names = Clef::Core::Pitch::VALID_NOTE_NAMES
        pitch_pos = (pitch.octave * 7) + note_names.index(pitch.note_name)
        ref_pos = (reference.octave * 7) + note_names.index(reference.note_name)
        baseline + (style.staff_space * 2) - ((pitch_pos - ref_pos) * (style.staff_space / 2.0))
      end
    end
  end
end
