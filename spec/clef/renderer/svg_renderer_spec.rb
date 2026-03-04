# frozen_string_literal: true

require "tmpdir"

RSpec.describe Clef::Renderer::SvgRenderer do
  it "renders an SVG file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.svg")
      described_class.new.render(simple_score, path)

      expect(File.exist?(path)).to be(true)
      expect(File.read(path)).to include("<svg")
    end
  end
end
