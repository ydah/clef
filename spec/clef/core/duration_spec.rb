# frozen_string_literal: true

RSpec.describe Clef::Core::Duration do
  it "returns rational base values" do
    expect(described_class.new(:whole).base_value).to eq(Rational(1, 1))
    expect(described_class.new(:half).base_value).to eq(Rational(1, 2))
    expect(described_class.new(:quarter).base_value).to eq(Rational(1, 4))
  end

  it "calculates dotted values" do
    expect(described_class.new(:quarter, dots: 1).length).to eq(Rational(3, 8))
    expect(described_class.new(:quarter, dots: 2).length).to eq(Rational(7, 16))
  end

  it "supports comparison" do
    expect(described_class.quarter).to be < described_class.half
    expect(described_class.half).to be < described_class.whole
  end

  it "rejects invalid arguments" do
    expect { described_class.new(:invalid) }.to raise_error(ArgumentError)
    expect { described_class.new(:quarter, dots: -1) }.to raise_error(ArgumentError)
  end

  it "supports 128th and 256th durations" do
    expect(described_class.from_lilypond(128).length).to eq(Rational(1, 128))
    expect(described_class.from_lilypond(256).length).to eq(Rational(1, 256))
  end
end
