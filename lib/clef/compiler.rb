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
      spacing = Clef::Layout::Spacing.new(timeline, @style)
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
        beams: build_beams
      }
      @plugins.run_hook(:on_after_layout, layout)
      layout
    end

    def build_columns(positions)
      sorted = positions.sort_by { |moment, _x| moment.value }
      sorted.each_cons(2).map do |(moment, x), (_next_moment, next_x)|
        { moment: moment, x: x, width: [next_x - x, @style.min_note_spacing].max, break_penalty: 0 }
      end + sorted.last(1).map do |moment, x|
        { moment: moment, x: x, width: @style.min_note_spacing, break_penalty: 0 }
      end
    end

    def build_beams
      @score.staves.to_h do |staff|
        [staff.id, staff.measures.to_h { |measure| [measure.number, measure_beams(measure)] }]
      end
    end

    def measure_beams(measure)
      measure.voices.to_h do |voice_id, voice|
        notes = voice.elements.select { |element| element.is_a?(Clef::Core::Note) && beamable_duration?(element.duration) }
        groups = Clef::Layout::BeamLayout.auto_beam(notes, measure.time_signature || Clef::Core::TimeSignature.new(4, 4))
        [voice_id, groups.select { |group| group.length > 1 }]
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
