# frozen_string_literal: true

RSpec.describe Clef::Ir::Timeline do
  it "returns events at requested moment" do
    timeline = described_class.new
    note = Clef::Core::Note.new(Clef::Core::Pitch.new(:c, 4), Clef::Core::Duration.quarter)
    moment = Clef::Ir::Moment.new(0)

    timeline.add(Clef::Ir::Event.new(moment: moment, element: note, staff_id: :staff1, voice_id: :v1))

    expect(timeline.events_at(moment).map(&:element)).to eq([note])
  end

  it "supports half-open event ranges" do
    timeline = described_class.new
    note = Clef::Core::Note.new(Clef::Core::Pitch.new(:c, 4), Clef::Core::Duration.quarter)
    first = Clef::Ir::Event.new(moment: Clef::Ir::Moment.new(0), element: note, staff_id: :staff1, voice_id: :v1)
    boundary = Clef::Ir::Event.new(moment: Clef::Ir::Moment.new(Rational(1, 4)), element: note, staff_id: :staff1, voice_id: :v1)

    timeline.add(first).add(boundary)

    expect(timeline.events_in_range(0, Rational(1, 4))).to eq([first])
    expect(timeline.events_between(0, Rational(1, 4))).to eq([first, boundary])
  end
end
