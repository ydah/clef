# frozen_string_literal: true

RSpec.describe Clef::Core::Score do
  it "flattens staves through staff groups" do
    score = described_class.new
    group = Clef::Core::StaffGroup.new
    group.add_staff(Clef::Core::Staff.new(:soprano))
    group.add_staff(Clef::Core::Staff.new(:bass))
    score.add_staff_group(group)

    expect(score.staves.map(&:id)).to eq(%i[soprano bass])
  end
end
