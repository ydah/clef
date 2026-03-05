# frozen_string_literal: true

require "tmpdir"
require "nokogiri"

RSpec.describe Clef::Renderer::SvgRenderer do
  it "renders an SVG file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.svg")
      described_class.new.render(simple_score, path)

      expect(File.exist?(path)).to be(true)
      expect(File.read(path)).to include("<svg")
    end
  end

  it "draws stems for quarter notes" do
    score = Clef.score do
      staff :melody, clef: :treble do
        time 4, 4
        play "c'4"
      end
    end

    document = render_svg_document(score)
    expect(vertical_lines(document)).not_to be_empty
  end

  it "does not draw stems for whole notes" do
    score = Clef.score do
      staff :melody, clef: :treble do
        time 4, 4
        play "c'1"
      end
    end

    document = render_svg_document(score)
    expect(vertical_lines(document)).to be_empty
  end

  it "draws half notes with hollow noteheads" do
    score = Clef.score do
      staff :melody, clef: :treble do
        time 4, 4
        play "c'2"
      end
    end

    document = render_svg_document(score)
    expect(document.xpath("//xmlns:ellipse").length).to eq(1)
  end

  it "draws accidentals and dotted notes" do
    score = Clef.score do
      staff :melody, clef: :treble do
        time 4, 4
        play "cis'4."
      end
    end

    document = render_svg_document(score)
    texts = document.xpath("//xmlns:text").map(&:text)
    circles = document.xpath("//xmlns:circle")

    expect(texts).to include("#")
    expect(circles.length).to eq(2)
  end

  it "draws chord stems and chord accidentals" do
    score = Clef.score do
      staff :melody, clef: :treble do
        time 4, 4
        voice do
          chord %w[C#4 E4 G4], :quarter, dots: 1
        end
      end
    end

    document = render_svg_document(score)
    texts = document.xpath("//xmlns:text").map(&:text)
    circles = document.xpath("//xmlns:circle")

    expect(vertical_lines(document)).not_to be_empty
    expect(texts).to include("#")
    expect(circles.length).to eq(4)
  end

  it "draws whole rests differently from non-whole rests" do
    whole_rest_score = Clef.score do
      staff :melody, clef: :treble do
        time 4, 4
        voice do
          rest :whole
        end
      end
    end
    quarter_rest_score = Clef.score do
      staff :melody, clef: :treble do
        time 4, 4
        voice do
          rest :quarter
        end
      end
    end

    whole_doc = render_svg_document(whole_rest_score)
    quarter_doc = render_svg_document(quarter_rest_score)

    expect(whole_doc.xpath("//xmlns:rect").length).to be > 0
    expect(quarter_doc.xpath("//xmlns:text").map(&:text)).to include("r")
  end

  def render_svg_document(score)
    xml = nil
    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.svg")
      described_class.new.render(score, path)
      xml = File.read(path)
    end
    Nokogiri::XML(xml)
  end

  def vertical_lines(document)
    document.xpath("//xmlns:line").select do |line|
      line["x1"] == line["x2"] && line["y1"] != line["y2"]
    end
  end
end
