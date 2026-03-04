# frozen_string_literal: true

require "tmpdir"

RSpec.describe Clef::Renderer::PdfRenderer do
  it "renders a PDF file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.pdf")
      described_class.new.render(simple_score, path)

      expect(File.exist?(path)).to be(true)
      expect(File.size(path)).to be > 0
    end
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
end
