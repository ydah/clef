# frozen_string_literal: true

RSpec.describe Clef::Layout::PageBreaker do
  it "breaks lines into pages" do
    lines = Array.new(10) { [{ width: 10 }] }
    pages = described_class.new.break_into_pages(lines, page_height: 100, line_height: 20)

    expect(pages.length).to eq(2)
    expect(pages.first.length).to eq(5)
  end
end
