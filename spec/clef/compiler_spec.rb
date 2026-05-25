# frozen_string_literal: true

require "tmpdir"

RSpec.describe Clef::Compiler do
  it "compiles score to PDF end-to-end" do
    score = simple_score

    Dir.mktmpdir do |dir|
      path = File.join(dir, "e2e.pdf")
      described_class.new(score).compile_to_pdf(path)

      expect(File.exist?(path)).to be(true)
      expect(File.size(path)).to be > 0
    end
  end

  it "compiles score to SVG end-to-end" do
    score = simple_score

    Dir.mktmpdir do |dir|
      path = File.join(dir, "e2e.svg")
      described_class.new(score).compile_to_svg(path)

      expect(File.exist?(path)).to be(true)
      expect(File.read(path)).to include("<svg")
    end
  end

  it "integrates line, page, and beam layout into the render layout" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        play "c'8 d'8 e'8 f'8 g'8 a'8 b'8 c''8"
      end
    end

    layout = described_class.new(score).send(:build_layout)

    expect(layout[:columns]).not_to be_empty
    expect(layout[:lines]).not_to be_empty
    expect(layout[:pages]).not_to be_empty
    expect(layout[:systems]).not_to be_empty
    expect(layout[:items].map(&:type)).to include(:clef, :time_signature, :barline)
    expect(layout[:beams].dig(:melody, 1, :default).first.length).to eq(4)
  end

  it "includes tuplet notes in beam layout" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        voice do
          tuplet 3, 2 do
            notes "c'8 d'8 e'8"
          end
          rest :half
          rest :quarter
        end
      end
    end

    layout = described_class.new(score).send(:build_layout)
    beam_group = layout[:beams].dig(:melody, 1, :default).first

    expect(beam_group.map(&:pitch).map(&:to_lilypond)).to eq(%w[c' d' e'])
  end

  it "builds multiple systems and pages when the style is constrained" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        play Array.new(8, "c'8 d'8 e'8 f'8").join(" | ")
      end
    end
    style = Clef::Engraving::Style.new(line_width: 80, system_gap: 80)

    layout = described_class.new(score, style: style).send(:build_layout)

    expect(layout[:systems].length).to be > 1
    expect(layout[:pages].length).to be >= 1
  end

  it "runs register_glyphs and after-render plugin hooks" do
    plugin = Class.new(Clef::Plugins::Base) do
      attr_reader :rendered_path

      def register_glyphs(glyph_table)
        glyph_table.register(:custom_plugin_glyph, "x")
      end

      def on_before_render(renderer)
        renderer.glyph_table.fetch(:custom_plugin_glyph)
      end

      def on_after_render(path)
        @rendered_path = path
      end
    end
    registry = Clef::Plugins::Registry.new
    instance = registry.register(plugin)

    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.svg")
      described_class.new(simple_score, plugins: registry).compile_to_svg(path)

      expect(instance.rendered_path).to eq(path)
    end
  end

  it "accepts plugin layout items and renders them in SVG" do
    plugin = Class.new(Clef::Plugins::Base) do
      def on_layout_items(_items)
        [
          Clef::Layout::Item.new(
            type: :text,
            moment: Clef::Ir::Moment.new(0),
            payload: {text: "plugin mark"}
          )
        ]
      end
    end
    registry = Clef::Plugins::Registry.new
    registry.register(plugin)

    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.svg")
      described_class.new(simple_score, plugins: registry).compile_to_svg(path)

      expect(File.read(path)).to include("plugin mark")
    end
  end
end
