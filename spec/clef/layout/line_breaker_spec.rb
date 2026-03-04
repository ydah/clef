# frozen_string_literal: true

RSpec.describe Clef::Layout::LineBreaker do
  it "splits columns into multiple lines" do
    columns = Array.new(10) { { width: 20.0, break_penalty: 0 } }
    lines = described_class.new.break_into_lines(columns, 80)

    expect(lines.length).to be > 1
    expect(lines.flatten).to eq(columns)
  end
end
