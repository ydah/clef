# frozen_string_literal: true

RSpec.describe Clef::Plugins::Registry do
  class DummyPlugin < Clef::Plugins::Base
    def self.plugin_name
      "dummy"
    end

    def on_before_layout(score)
      score.metadata[:hooked] = true
    end
  end

  it "registers plugins and runs hooks" do
    registry = described_class.new
    score = Clef::Core::Score.new

    registry.register(DummyPlugin)
    registry.run_hook(:on_before_layout, score)

    expect(score.metadata[:hooked]).to be(true)
  end
end
