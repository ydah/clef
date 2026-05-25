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

  it "rejects duplicate staff ids added outside the same group" do
    score = described_class.new
    group = Clef::Core::StaffGroup.new([Clef::Core::Staff.new(:melody)])
    score.add_staff_group(group)

    expect do
      score.add_staff(Clef::Core::Staff.new(:melody))
    end.to raise_error(ArgumentError, /duplicate staff id/)
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

  it "validates lyrics against notes inside tuplets" do
    score = Clef.score do
      staff :melody do
        time 1, 4
        voice :lead do
          tuplet 3, 2 do
            notes "c'8 d'8 e'8"
          end
        end
        lyrics :lead, "la la la"
      end
    end

    expect(score.validate.warnings.map(&:message)).not_to include(/lyrics/)
  end

  it "validates lyrics against chord events" do
    score = Clef.score do
      staff :melody do
        time 2, 4
        voice :lead do
          chord %w[C4 E4 G4], :half
        end
        lyrics :lead, "sing"
      end
    end

    expect(score.validate.warnings.map(&:message)).not_to include(/lyrics/)
  end

  it "does not count lyric hyphens as note-consuming syllables" do
    score = Clef.score do
      staff :melody do
        time 2, 4
        voice :lead do
          notes "c'4 d'4"
        end
        lyrics :lead, "la -- la"
      end
    end

    expect(score.validate.warnings.map(&:message)).not_to include(/lyrics/)
  end

  it "routes to exporters by file extension" do
    score = described_class.new

    expect { score.to_format("score.unknown") }.to raise_error(ArgumentError, /unsupported output format/)
  end

  it "duplicates assigned metadata hashes" do
    source = {prepared: true}
    score = described_class.new(metadata: source)
    source[:prepared] = false

    expect(score.metadata[:prepared]).to be(true)

    replacement = {title: "Sketch"}
    score.metadata = replacement
    replacement[:title] = "Changed"

    expect(score.metadata[:title]).to eq("Sketch")
  end
end
