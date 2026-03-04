# frozen_string_literal: true

RSpec.describe Clef::Ir::MusicTree do
  it "builds timeline moments from quarter notes" do
    score = Clef.score do
      staff :melody do
        time 4, 4
        voice do
          notes "c'4 d'4 e'4 f'4"
        end
      end
    end

    timeline = described_class.build(score)
    moments = timeline.each_moment.map(&:value)

    expect(moments).to include(Rational(0, 1), Rational(1, 4), Rational(1, 2), Rational(3, 4))
  end

  it "merges multiple voices" do
    score = Clef::Core::Score.new
    staff = Clef::Core::Staff.new(:s)
    measure = Clef::Core::Measure.new(1)
    measure.voice(:v1).add(Clef::Core::Rest.new(Clef::Core::Duration.quarter))
    measure.voice(:v2).add(Clef::Core::Note.new(Clef::Core::Pitch.new(:c, 4), Clef::Core::Duration.quarter))
    staff.add_measure(measure)
    score.add_staff(staff)

    timeline = described_class.build(score)
    events = timeline.events_at(0)

    expect(events.map(&:voice_id)).to include(:v1, :v2)
  end
end
