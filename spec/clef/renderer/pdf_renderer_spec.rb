# frozen_string_literal: true

require "tmpdir"
require "stringio"

RSpec.describe Clef::Renderer::PdfRenderer do
  it "renders a PDF file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.pdf")
      described_class.new.render(simple_score, path)

      expect(File.exist?(path)).to be(true)
      expect(File.size(path)).to be > 0
    end
  end

  it "writes PDF to IO objects and validates missing directories" do
    io = StringIO.new

    described_class.new.render(simple_score, io)

    expect(io.string.bytesize).to be > 0
    expect do
      described_class.new.render(simple_score, "/missing-clef-dir/score.pdf")
    end.to raise_error(ArgumentError, /output directory/)
  end

  it "draws five staff lines" do
    renderer = described_class.new
    pdf = instance_double("Prawn::Document")
    bounds = instance_double("Prawn::Document::BoundingBox", right: 600)
    allow(pdf).to receive(:bounds).and_return(bounds)
    allow(pdf).to receive(:stroke_line)

    renderer.draw_staff_lines(pdf, 100)

    expect(pdf).to have_received(:stroke_line).exactly(5).times
  end

  it "maps clef reference pitch onto the clef reference line" do
    renderer = described_class.new
    clef = Clef::Core::Clef.new(:treble)
    y = renderer.send(:pitch_to_y, clef.reference_pitch, 100, clef)

    expect(y).to eq(80)
  end

  it "moves notes by half staff space per diatonic step" do
    renderer = described_class.new
    clef = Clef::Core::Clef.new(:treble)
    c5 = Clef::Core::Pitch.new(:c, 5)
    y = renderer.send(:pitch_to_y, c5, 100, clef)

    expect(y).to eq(75)
  end

  it "formats metadata without natural key text for C major" do
    renderer = described_class.new
    staff = Clef::Core::Staff.new(:melody, clef: Clef::Core::Clef.new(:treble))
    staff.key_signature = Clef::Core::KeySignature.new(:c, :major)
    staff.time_signature = Clef::Core::TimeSignature.new(4, 4)

    expect(renderer.send(:metadata_text, staff)).to eq("4/4")
  end

  it "formats metadata with compact accidental count for sharp keys" do
    renderer = described_class.new
    staff = Clef::Core::Staff.new(:melody, clef: Clef::Core::Clef.new(:treble))
    staff.key_signature = Clef::Core::KeySignature.new(:g, :major)
    staff.time_signature = Clef::Core::TimeSignature.new(4, 4)

    expect(renderer.send(:metadata_text, staff)).to eq("1# 4/4")
  end

  it "draws half notes with hollow noteheads" do
    renderer = described_class.new
    pdf = instance_double("Prawn::Document")
    allow(pdf).to receive(:fill_color)
    allow(pdf).to receive(:circle)
    allow(pdf).to receive(:fill)
    allow(pdf).to receive(:ellipse)
    allow(pdf).to receive(:fill_and_stroke)

    renderer.draw_notehead(pdf, 100, 100, duration: Clef::Core::Duration.half)

    expect(pdf).to have_received(:ellipse)
    expect(pdf).not_to have_received(:circle)
  end

  it "draws quarter notes with filled noteheads" do
    renderer = described_class.new
    pdf = instance_double("Prawn::Document")
    allow(pdf).to receive(:fill_color)
    allow(pdf).to receive(:circle)
    allow(pdf).to receive(:fill)
    allow(pdf).to receive(:ellipse)
    allow(pdf).to receive(:fill_and_stroke)

    renderer.draw_notehead(pdf, 100, 100, duration: Clef::Core::Duration.quarter)

    expect(pdf).to have_received(:circle)
    expect(pdf).not_to have_received(:ellipse)
  end
end
