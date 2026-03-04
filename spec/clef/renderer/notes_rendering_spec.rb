# frozen_string_literal: true

require "tmpdir"

RSpec.describe "notes rendering" do
  it "renders twinkle opening into PDF" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        play "c'4 c'4 g'4 g'4 | a'4 a'4 g'2"
      end
    end

    Dir.mktmpdir do |dir|
      path = File.join(dir, "twinkle.pdf")
      score.to_pdf(path)

      expect(File.exist?(path)).to be(true)
      expect(File.size(path)).to be > 0
    end
  end
end
