# frozen_string_literal: true

RSpec.describe Clef::Ir::Moment do
  it "supports arithmetic and comparison" do
    moment = described_class.new(Rational(1, 4))

    expect(moment + Rational(1, 4)).to eq(described_class.new(Rational(1, 2)))
    expect(moment - described_class.new(0)).to eq(Rational(1, 4))
  end
end
