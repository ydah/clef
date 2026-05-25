# frozen_string_literal: true

RSpec.describe Clef::Layout::SystemLayout do
  it "assigns staff offsets to each rendered system" do
    score = Clef.score do
      staff :upper do
        time 4, 4
        play "c'1"
      end

      staff :lower do
        time 4, 4
        play "c1"
      end
    end
    positions = { Clef::Ir::Moment.new(0) => 0.0, Clef::Ir::Moment.new(1) => 100.0 }
    line = [{ moment: Clef::Ir::Moment.new(0), width: 100.0 }, { moment: Clef::Ir::Moment.new(1), width: 24.0 }]

    systems = described_class.new(
      score,
      pages: [[line]],
      positions: positions,
      style: Clef::Engraving::Style.default
    ).build

    expect(systems.length).to eq(1)
    expect(systems.first.staff_offset(:upper)).to eq(0)
    expect(systems.first.staff_offset(:lower)).to eq(Clef::Engraving::Style.default.staff_gap)
    expect(systems.first.include_moment?(Clef::Ir::Moment.new(1))).to be(true)
  end
end
