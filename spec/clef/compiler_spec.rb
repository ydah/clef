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
end
