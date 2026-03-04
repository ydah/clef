# frozen_string_literal: true

RSpec.describe Clef::Core::Rest do
  it "stores duration" do
    rest = described_class.new(Clef::Core::Duration.half)

    expect(rest.length).to eq(Rational(1, 2))
  end
end
