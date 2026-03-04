# frozen_string_literal: true

RSpec.describe Clef::Core::TimeSignature do
  it "returns measure length" do
    expect(described_class.new(3, 4).measure_length).to eq(Rational(3, 4))
  end

  it "rejects invalid denominator" do
    expect { described_class.new(4, 3) }.to raise_error(ArgumentError)
  end
end
