# frozen_string_literal: true

module Clef
  class Compiler
    # @param score [Clef::Core::Score]
    # @param style [Clef::Engraving::Style]
    # @param plugins [Clef::Plugins::Registry]
    def initialize(score, style: Clef::Engraving::Style.default, plugins: Clef.plugins)
      @score = score
      @style = style
      @plugins = plugins
    end

    # @param path [String]
    # @return [String]
    def compile_to_pdf(path)
      layout = build_layout
      renderer = Clef::Renderer::PdfRenderer.new(style: @style)
      @plugins.run_hook(:register_glyphs, renderer.glyph_table)
      @plugins.run_hook(:on_before_render, renderer)
      renderer.render(@score, path, positions: layout[:positions], layout: layout)
      @plugins.run_hook(:on_after_render, path)
      path
    end

    # @param path [String]
    # @return [String]
    def compile_to_svg(path)
      layout = build_layout
      renderer = Clef::Renderer::SvgRenderer.new(style: @style)
      @plugins.run_hook(:register_glyphs, renderer.glyph_table)
      @plugins.run_hook(:on_before_render, renderer)
      renderer.render(@score, path, positions: layout[:positions], layout: layout)
      @plugins.run_hook(:on_after_render, path)
      path
    end

    private

    def build_layout
      @plugins.run_hook(:on_before_layout, @score)
      timeline = Clef::Ir::MusicTree.build(@score)
      timeline.sort!
      layout_items = build_layout_items
      plugin_items = @plugins.run_hook(:on_layout_items, layout_items).flatten.compact
      layout_items.concat(plugin_items)
      spacing = Clef::Layout::Spacing.new(timeline, @style, extra_moments: layout_items.map(&:moment))
      spacing.stretch_to_fit(@style.line_width)
      positions = spacing.compute
      columns = build_columns(positions)
      lines = Clef::Layout::LineBreaker.new.break_into_lines(columns, @style.line_width)
      pages = Clef::Layout::PageBreaker.new.break_into_pages(
        lines,
        page_height: page_height,
        line_height: @style.system_gap
      )
      layout = {
        timeline: timeline,
        spacing: spacing,
        positions: positions,
        columns: columns,
        lines: lines,
        pages: pages,
        systems: Clef::Layout::SystemLayout.new(@score, pages: pages, positions: positions, style: @style).build,
        items: layout_items,
        beams: build_beams
      }
      @plugins.run_hook(:on_after_layout, layout)
      layout
    end

    def build_columns(positions)
      sorted = positions.sort_by { |moment, _x| moment.value }
      sorted.each_cons(2).map do |(moment, x), (_next_moment, next_x)|
        {moment: moment, x: x, width: [next_x - x, @style.min_note_spacing].max, break_penalty: 0}
      end + sorted.last(1).map do |moment, x|
        {moment: moment, x: x, width: @style.min_note_spacing, break_penalty: 0}
      end
    end

    def build_beams
      @score.staves.to_h do |staff|
        [staff.id, staff.measures.to_h { |measure| [measure.number, measure_beams(measure)] }]
      end
    end

    def build_layout_items
      @score.staves.flat_map do |staff|
        current = Clef::Ir::Moment.new(0)
        staff.measures.flat_map do |measure|
          items = metadata_items(staff, measure, current)
          current += measure_length_for(measure)
          items << Clef::Layout::Item.new(type: :barline, moment: current, staff_id: staff.id,
            measure_number: measure.number)
          items
        end
      end
    end

    def metadata_items(staff, measure, moment)
      [
        Clef::Layout::Item.new(type: :clef, moment: moment, staff_id: staff.id,
          measure_number: measure.number, payload: {clef: measure.clef || staff.clef}),
        Clef::Layout::Item.new(type: :key_signature, moment: moment, staff_id: staff.id,
          measure_number: measure.number, payload: {key_signature: measure.key_signature || staff.key_signature}),
        Clef::Layout::Item.new(type: :time_signature, moment: moment, staff_id: staff.id,
          measure_number: measure.number, payload: {time_signature: measure.time_signature || staff.time_signature})
      ].reject { |item| item.payload.values.all?(&:nil?) }
    end

    def measure_length_for(measure)
      return measure.time_signature.measure_length if measure.time_signature

      measure.voices.values.map(&:total_length).max || Rational(0, 1)
    end

    def measure_beams(measure)
      measure.voices.to_h do |voice_id, voice|
        notes = beamable_notes(voice.elements)
        groups = Clef::Layout::BeamLayout.auto_beam(notes, measure.time_signature || Clef::Core::TimeSignature.new(4, 4))
        [voice_id, groups.select { |group| group.length > 1 }]
      end
    end

    def beamable_notes(elements)
      elements.flat_map do |element|
        case element
        when Clef::Core::Note
          beamable_duration?(element.duration) ? [element] : []
        when Clef::Core::Tuplet
          beamable_notes(element.elements)
        else
          []
        end
      end
    end

    def beamable_duration?(duration)
      %i[eighth sixteenth thirty_second sixty_fourth one_twenty_eighth two_fifty_sixth].include?(duration.base)
    end

    def page_height
      case @style.page_size
      when Array then @style.page_size.last.to_f - (@style.margin * 2)
      else 760.0
      end
    end
  end
end
