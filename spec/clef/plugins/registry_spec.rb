# frozen_string_literal: true

class RegistrySpecDummyPlugin < Clef::Plugins::Base
  def self.plugin_name
    "dummy"
  end

  def on_before_layout(score)
    score.metadata[:hooked] = true
  end
end

RSpec.describe Clef::Plugins::Registry do
  it "registers plugins and runs hooks" do
    registry = described_class.new
    score = Clef::Core::Score.new

    registry.register(RegistrySpecDummyPlugin)
    registry.run_hook(:on_before_layout, score)

    expect(score.metadata[:hooked]).to be(true)
  end

  it "registers plugin instances and can unregister or clear them" do
    registry = described_class.new
    plugin = RegistrySpecDummyPlugin.new

    registry.register(plugin)
    expect(registry.plugins).to eq([plugin])

    expect(registry.unregister(RegistrySpecDummyPlugin)).to eq(plugin)
    expect(registry.plugins).to be_empty

    registry.register(RegistrySpecDummyPlugin)
    registry.clear
    expect(registry.plugins).to be_empty
  end

  it "orders plugins by priority and registration order" do
    registry = described_class.new
    calls = []
    first = Class.new(Clef::Plugins::Base) { define_method(:on_before_layout) { |_score| calls << :first } }
    second = Class.new(Clef::Plugins::Base) { define_method(:on_before_layout) { |_score| calls << :second } }

    registry.register(second, priority: 10)
    registry.register(first, priority: 0)
    registry.run_hook(:on_before_layout, Clef::Core::Score.new)

    expect(calls).to eq(%i[first second])
  end

  it "collects hook errors when configured" do
    registry = described_class.new(error_policy: :collect)
    failing = Class.new(Clef::Plugins::Base) do
      def on_before_layout(_score)
        raise "boom"
      end
    end

    registry.register(failing)
    results = registry.run_hook(:on_before_layout, Clef::Core::Score.new)

    expect(results).to eq([nil])
    expect(registry.errors.first[:error].message).to eq("boom")
  end
end
