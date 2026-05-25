# frozen_string_literal: true

RSpec.describe Clef do
  it "has a version number" do
    expect(Clef::VERSION).not_to be nil
  end

  it "tracks the last score built by the DSL" do
    score = described_class.score do
      staff :melody do
        play "c'1"
      end
    end

    expect(described_class.last_score).to equal(score)
  end
end
