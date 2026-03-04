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
      renderer.render(@score, path, positions: layout[:positions])
      path
    end

    # @param path [String]
    # @return [String]
    def compile_to_svg(path)
      layout = build_layout
      renderer = Clef::Renderer::SvgRenderer.new(style: @style)
      @plugins.run_hook(:on_before_render, renderer)
      renderer.render(@score, path, positions: layout[:positions])
      path
    end

    private

    def build_layout
      @plugins.run_hook(:on_before_layout, @score)
      timeline = Clef::Ir::MusicTree.build(@score)
      spacing = Clef::Layout::Spacing.new(timeline, @style)
      positions = spacing.compute
      layout = { timeline: timeline, spacing: spacing, positions: positions }
      @plugins.run_hook(:on_after_layout, layout)
      layout
    end
  end
end
