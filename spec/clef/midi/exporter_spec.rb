# frozen_string_literal: true

require "tmpdir"

RSpec.describe Clef::Midi::Exporter do
  it "exports score to midi file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.mid")
      described_class.new(simple_score).export(path)

      expect(File.exist?(path)).to be(true)
      expect(File.size(path)).to be > 0
    end
  end
end
