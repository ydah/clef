# frozen_string_literal: true

RSpec.describe Clef::Core::Staff do
  it "stores multiple measures" do
    staff = described_class.new(:piano)
    staff.add_measure(Clef::Core::Measure.new(1))
    staff.add_measure(Clef::Core::Measure.new(2))

    expect(staff.measures.map(&:number)).to eq([1, 2])
  end

  it "duplicates assigned metadata hashes" do
    source = {instrument: "Piano"}
    staff = described_class.new(:piano)
    staff.metadata = source
    source[:instrument] = "Violin"

    expect(staff.metadata[:instrument]).to eq("Piano")
  end

  it "does not expose the mutable measure store" do
    staff = described_class.new(:piano)
    staff.add_measure(Clef::Core::Measure.new(1))

    expect(staff.measures).to be_frozen
    expect { staff.measures << Clef::Core::Measure.new(2) }.to raise_error(FrozenError)
    expect(staff.measures.map(&:number)).to eq([1])
  end
end
