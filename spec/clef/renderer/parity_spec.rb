# frozen_string_literal: true

require "nokogiri"
require "stringio"

class RendererParityPdf
  Bounds = Struct.new(:right, :top, keyword_init: true)

  attr_reader :bounds, :cursor, :text_boxes, :circles, :ellipses

  def initialize
    @bounds = Bounds.new(right: 600, top: 760)
    @cursor = 720
    @text_boxes = []
    @circles = []
    @ellipses = []
  end

  def text_box(text, **_options)
    text_boxes << text.to_s
  end

  def stroke_line(*_args)
  end

  def fill_color(*_args)
  end

  def circle(*args)
    circles << args
  end

  def fill
  end

  def ellipse(*args)
    ellipses << args
  end

  def fill_and_stroke
  end

  def width_of(text, size:)
    text.length * size * 0.5
  end
end

RSpec.describe "renderer parity" do
  it "draws matching headers and notehead counts in PDF and SVG" do
    score = Clef.score do
      title "Parity"
      composer "Clef"
      staff :melody do
        time 4, 4
        play "c'4 d'2 r4"
      end
    end

    pdf = RendererParityPdf.new
    Clef::Renderer::PdfRenderer.new.draw_score(pdf, score, nil)
    svg = render_svg(score)

    expect(pdf.text_boxes).to include("Parity", "Clef")
    expect(svg.xpath("//*[@class='title' or @class='composer']").map(&:text)).to include("Parity", "Clef")
    expect(pdf.circles.length + pdf.ellipses.length).to eq(svg.xpath("//*[contains(@class, 'notehead')]").length)
  end

  def render_svg(score)
    io = StringIO.new
    Clef::Renderer::SvgRenderer.new.render(score, io)
    Nokogiri::XML(io.string)
  end
end
