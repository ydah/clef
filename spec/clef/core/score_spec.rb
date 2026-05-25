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

  it "validates overflow and underfull measures" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        voice do
          rest :quarter
        end
      end
    end

    result = score.validate

    expect(result.ok?).to be(true)
    expect(result.warnings.map(&:message)).to include(/shorter than time signature length/)
  end

  it "routes to exporters by file extension" do
    score = described_class.new

    expect { score.to_format("score.unknown") }.to raise_error(ArgumentError, /unsupported output format/)
  end
end
