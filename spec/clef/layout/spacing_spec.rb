# frozen_string_literal: true

RSpec.describe Clef::Layout::Spacing do
  let(:style) { Clef::Engraving::Style.default }

  def build_timeline(durations)
    timeline = Clef::Ir::Timeline.new
    cursor = Clef::Ir::Moment.new(0)
    durations.each do |duration|
      note = Clef::Core::Note.new(Clef::Core::Pitch.new(:c, 4), duration)
      timeline.add(Clef::Ir::Event.new(moment: cursor, element: note, staff_id: :s, voice_id: :v))
      cursor += duration.length
    end
    timeline
  end

  it "keeps equal durations equally spaced" do
    timeline = build_timeline([Clef::Core::Duration.quarter] * 4)
    positions = described_class.new(timeline, style).compute
    deltas = positions.values.each_cons(2).map { |left, right| (right - left).round(4) }

    expect(deltas.uniq.size).to eq(1)
  end

  it "gives quarter notes more space than eighth notes" do
    durations = [Clef::Core::Duration.eighth, Clef::Core::Duration.quarter, Clef::Core::Duration.eighth]
    timeline = build_timeline(durations)
    positions = described_class.new(timeline, style).compute.values

    expect(positions[2] - positions[1]).to be > (positions[1] - positions[0])
  end

  it "stretches to fit target width" do
    timeline = build_timeline([Clef::Core::Duration.quarter] * 4)
    spacing = described_class.new(timeline, style)

    spacing.stretch_to_fit(500)
    width = spacing.compute.values.max

    expect(width).to be_within(0.1).of(500)
  end
end
