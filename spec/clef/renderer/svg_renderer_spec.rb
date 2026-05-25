# frozen_string_literal: true

require "tmpdir"
require "nokogiri"
require "stringio"

RSpec.describe Clef::Renderer::SvgRenderer do
  it "renders an SVG file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.svg")
      described_class.new.render(simple_score, path)

      expect(File.exist?(path)).to be(true)
      expect(File.read(path)).to include("<svg")
    end
  end

  it "writes SVG to IO objects and validates missing directories" do
    io = StringIO.new

    described_class.new.render(simple_score, io)

    expect(io.string).to include("<svg")
    expect do
      described_class.new.render(simple_score, "/missing-clef-dir/score.svg")
    end.to raise_error(ArgumentError, /output directory/)
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
    expect(circles.length).to eq(6)
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

  it "renders clef, key signature, time signature, and barlines structurally" do
    score = Clef.score do
      staff :melody, clef: :bass do
        key :bes, :major
        time 3, 4
        play "c'2."
      end
    end

    document = render_svg_document(score)

    expect(document.xpath("//*[@class='clef']").map(&:text)).to include("F")
    expect(document.xpath("//*[contains(@class, 'key-signature')]").length).to eq(2)
    expect(document.xpath("//*[contains(@class, 'time-signature')]").map(&:text)).to include("3", "4")
    expect(document.xpath("//*[@class='barline']").length).to eq(1)
  end

  it "renders multiple voices and lyrics" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        voice :upper do
          notes "c'4 d'4 e'4 f'4"
        end
        voice :lower do
          notes "g4 a4 b4 c'4"
        end
        lyrics :upper, "la la la la"
      end
    end

    document = render_svg_document(score)

    expect(document.xpath("//*[contains(@class, 'notehead')]").length).to eq(8)
    expect(document.xpath("//*[@class='lyric']").map(&:text)).to eq(%w[la la la la])
  end

  it "renders beams, flags, ties, and slurs" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        play "( c'8~ c'8 ) d'8 e'8 r4 c'16"
      end
    end

    document = nil
    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.svg")
      Clef::Compiler.new(score).compile_to_svg(path)
      document = Nokogiri::XML(File.read(path))
    end

    expect(document.xpath("//*[@class='beam']").length).to be > 0
    expect(document.xpath("//*[@class='flag']").length).to be > 0
    expect(document.xpath("//*[@class='tie']").length).to eq(1)
    expect(document.xpath("//*[@class='slur']").length).to eq(1)
  end

  it "renders constrained scores across multiple systems" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        play Array.new(6, "c'8 d'8 e'8 f'8").join(" | ")
      end
    end

    document = nil
    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.svg")
      Clef::Compiler.new(score, style: Clef::Engraving::Style.new(line_width: 80)).compile_to_svg(path)
      document = Nokogiri::XML(File.read(path))
    end

    expect(document.xpath("//*[@class='clef']").length).to be > 1
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
      line["class"] == "stem" && line["x1"] == line["x2"] && line["y1"] != line["y2"]
    end
  end
end
