# frozen_string_literal: true

require "tmpdir"
require "stringio"

RSpec.describe Clef::Renderer::PdfRenderer do
  it "renders a PDF file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "score.pdf")
      described_class.new.render(simple_score, path)

      expect(File.exist?(path)).to be(true)
      expect(File.size(path)).to be > 0
    end
  end

  it "writes PDF to IO objects and validates missing directories" do
    io = StringIO.new

    described_class.new.render(simple_score, io)

    expect(io.string.bytesize).to be > 0
    expect do
      described_class.new.render(simple_score, "/missing-clef-dir/score.pdf")
    end.to raise_error(ArgumentError, /output directory/)
  end

  it "draws five staff lines" do
    renderer = described_class.new
    pdf = instance_double("Prawn::Document")
    bounds = instance_double("Prawn::Document::BoundingBox", right: 600)
    allow(pdf).to receive(:bounds).and_return(bounds)
    allow(pdf).to receive(:stroke_line)

    renderer.draw_staff_lines(pdf, 100)

    expect(pdf).to have_received(:stroke_line).exactly(5).times
  end

  it "maps clef reference pitch onto the clef reference line" do
    renderer = described_class.new
    clef = Clef::Core::Clef.new(:treble)
    y = renderer.send(:pitch_to_y, clef.reference_pitch, 100, clef)

    expect(y).to eq(80)
  end

  it "moves notes by half staff space per diatonic step" do
    renderer = described_class.new
    clef = Clef::Core::Clef.new(:treble)
    c5 = Clef::Core::Pitch.new(:c, 5)
    y = renderer.send(:pitch_to_y, c5, 100, clef)

    expect(y).to eq(75)
  end

  it "formats metadata without natural key text for C major" do
    renderer = described_class.new
    staff = Clef::Core::Staff.new(:melody, clef: Clef::Core::Clef.new(:treble))
    staff.key_signature = Clef::Core::KeySignature.new(:c, :major)
    staff.time_signature = Clef::Core::TimeSignature.new(4, 4)

    expect(renderer.send(:metadata_text, staff)).to eq("4/4")
  end

  it "formats metadata with compact accidental count for sharp keys" do
    renderer = described_class.new
    staff = Clef::Core::Staff.new(:melody, clef: Clef::Core::Clef.new(:treble))
    staff.key_signature = Clef::Core::KeySignature.new(:g, :major)
    staff.time_signature = Clef::Core::TimeSignature.new(4, 4)

    expect(renderer.send(:metadata_text, staff)).to eq("1# 4/4")
  end

  it "draws half notes with hollow noteheads" do
    renderer = described_class.new
    pdf = instance_double("Prawn::Document")
    allow(pdf).to receive(:fill_color)
    allow(pdf).to receive(:circle)
    allow(pdf).to receive(:fill)
    allow(pdf).to receive(:ellipse)
    allow(pdf).to receive(:fill_and_stroke)

    renderer.draw_notehead(pdf, 100, 100, duration: Clef::Core::Duration.half)

    expect(pdf).to have_received(:ellipse)
    expect(pdf).not_to have_received(:circle)
  end

  it "draws quarter notes with filled noteheads" do
    renderer = described_class.new
    pdf = instance_double("Prawn::Document")
    allow(pdf).to receive(:fill_color)
    allow(pdf).to receive(:circle)
    allow(pdf).to receive(:fill)
    allow(pdf).to receive(:ellipse)
    allow(pdf).to receive(:fill_and_stroke)

    renderer.draw_notehead(pdf, 100, 100, duration: Clef::Core::Duration.quarter)

    expect(pdf).to have_received(:circle)
    expect(pdf).not_to have_received(:ellipse)
  end

  it "draws one PDF dot per duration dot" do
    renderer = described_class.new
    pdf = instance_double("Prawn::Document")
    allow(pdf).to receive(:circle)
    allow(pdf).to receive(:fill)

    renderer.send(:draw_dot, pdf, Clef::Core::Duration.new(:quarter, dots: 2), 100, 100)

    expect(pdf).to have_received(:circle).with([108, 100], 1)
    expect(pdf).to have_received(:circle).with([111, 100], 1)
    expect(pdf).to have_received(:fill).twice
  end

  it "draws marcato and fermata articulations without text fallback" do
    renderer = described_class.new
    pdf = instance_double("Prawn::Document")
    allow(pdf).to receive(:stroke_line)
    allow(pdf).to receive(:circle)
    allow(pdf).to receive(:fill)
    allow(pdf).to receive(:text_box)

    renderer.send(:draw_articulations, pdf, %i[marcato fermata], 100, 100)

    expect(pdf).to have_received(:stroke_line).at_least(4).times
    expect(pdf).to have_received(:circle).with([100, 112], 1.2)
    expect(pdf).not_to have_received(:text_box).with("marcato", any_args)
    expect(pdf).not_to have_received(:text_box).with("fermata", any_args)
  end

  it "draws lyrics for notes inside tuplets" do
    score = Clef.score do
      staff :melody do
        time 1, 4
        voice :lead do
          tuplet 3, 2 do
            notes "c'8 d'8 e'8"
          end
        end
        lyrics :lead, "tri o let"
      end
    end
    staff = score.staves.first
    notes = staff.measures.first.voices[:lead].elements.first.elements
    note_points = notes.each_with_index.to_h { |note, index| [note.object_id, [100 + (index * 20), 80]] }
    renderer = described_class.new
    pdf = instance_double("Prawn::Document")
    allow(pdf).to receive(:text_box)

    renderer.send(:draw_lyrics, pdf, staff, note_points, 100)

    expect(pdf).to have_received(:text_box).with("tri", hash_including(size: 8, align: :center))
    expect(pdf).to have_received(:text_box).with("o", hash_including(size: 8, align: :center))
    expect(pdf).to have_received(:text_box).with("let", hash_including(size: 8, align: :center))
  end

  it "draws lyrics for chord events" do
    score = Clef.score do
      staff :melody do
        time 1, 4
        voice :lead do
          chord %w[C4 E4 G4], :quarter
        end
        lyrics :lead, "sing"
      end
    end
    staff = score.staves.first
    chord = staff.measures.first.voices[:lead].elements.first
    renderer = described_class.new
    pdf = instance_double("Prawn::Document")
    allow(pdf).to receive(:text_box)

    renderer.send(:draw_lyrics, pdf, staff, {chord.object_id => [100, 80]}, 100)

    expect(pdf).to have_received(:text_box).with("sing", hash_including(size: 8, align: :center))
  end

  it "draws lyric hyphens and extenders" do
    score = Clef.score do
      staff :melody do
        time 3, 4
        voice :lead do
          notes "c'4 d'4 e'4"
        end
        lyrics :lead, "sing _ -- on"
      end
    end
    staff = score.staves.first
    elements = staff.measures.first.voices[:lead].elements
    note_points = elements.each_with_index.to_h { |note, index| [note.object_id, [100 + (index * 20), 80]] }
    renderer = described_class.new
    pdf = instance_double("Prawn::Document")
    allow(pdf).to receive(:text_box)
    allow(pdf).to receive(:stroke_line)

    renderer.send(:draw_lyrics, pdf, staff, note_points, 100)

    expect(pdf).to have_received(:text_box).with("sing", hash_including(size: 8, align: :center))
    expect(pdf).to have_received(:text_box).with("on", hash_including(size: 8, align: :center))
    expect(pdf).to have_received(:text_box).with("-", hash_including(size: 8, align: :center))
    expect(pdf).to have_received(:stroke_line)
  end

  it "draws tie and slur notation objects" do
    c4 = Clef::Core::Pitch.new(:c, 4)
    d4 = Clef::Core::Pitch.new(:d, 4)
    first = Clef::Core::Note.new(c4, Clef::Core::Duration.quarter)
    tied = Clef::Core::Note.new(c4, Clef::Core::Duration.quarter)
    slurred = Clef::Core::Note.new(d4, Clef::Core::Duration.quarter)
    note_points = {
      first.object_id => [100, 80],
      tied.object_id => [130, 80],
      slurred.object_id => [160, 76]
    }
    renderer = described_class.new
    pdf = instance_double("Prawn::Document")
    allow(pdf).to receive(:stroke_curve)

    renderer.draw_ties(pdf, [Clef::Notation::Tie.new(first, tied)], note_points: note_points)
    renderer.draw_slurs(pdf, [Clef::Notation::Slur.new(first, slurred)], note_points: note_points)

    expect(pdf).to have_received(:stroke_curve).twice
  end

  it "uses duration-specific SMuFL rest glyphs" do
    glyph_table = Clef::Engraving::GlyphTable.new(glyphs: {
      rest_quarter: "quarter",
      rest_8th: "eighth",
      rest_16th: "sixteenth"
    })
    renderer = described_class.new(glyph_table: glyph_table)
    renderer.instance_variable_set(:@smufl_enabled, true)
    pdf = instance_double("Prawn::Document")
    allow(pdf).to receive(:text_box)

    renderer.draw_rest(pdf, Clef::Core::Rest.new(Clef::Core::Duration.eighth), 100, 100)
    renderer.draw_rest(pdf, Clef::Core::Rest.new(Clef::Core::Duration.sixteenth), 100, 100)

    expect(pdf).to have_received(:text_box).with("eighth", at: kind_of(Array), size: 14)
    expect(pdf).to have_received(:text_box).with("sixteenth", at: kind_of(Array), size: 14)
  end
end
