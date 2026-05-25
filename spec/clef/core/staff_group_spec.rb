# frozen_string_literal: true

RSpec.describe Clef::Core::StaffGroup do
  it "does not expose the mutable staff store" do
    group = described_class.new
    group.add_staff(Clef::Core::Staff.new(:melody))

    expect(group.staves).to be_frozen
    expect { group.staves << Clef::Core::Staff.new(:bass) }.to raise_error(FrozenError)
    expect(group.staves.map(&:id)).to eq([:melody])
  end
end
