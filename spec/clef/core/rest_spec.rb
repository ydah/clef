# frozen_string_literal: true

RSpec.describe Clef::Core::Rest do
  it "stores duration" do
    rest = described_class.new(Clef::Core::Duration.half)

    expect(rest.length).to eq(Rational(1, 2))
  end

  it "scales length by multi-measure count" do
    rest = described_class.new(Clef::Core::Duration.whole, kind: :multi_measure, measures: 4)

    expect(rest.length).to eq(Rational(4, 1))
  end
end
