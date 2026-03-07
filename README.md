# Clef

Clef is a Ruby toolkit for building small scores with a Ruby DSL and exporting them to PDF, SVG, or MIDI.

## Current Feature Set

- Core score model for pitches, durations, notes, rests, chords, measures, staves, staff groups, and tempo
- Ruby DSL via `Clef.score`
- LilyPond-like shorthand through `play` and `notes`
- Basic LilyPond import through `Clef::Parser::LilypondParser`
- PDF rendering with Prawn
- SVG rendering with Nokogiri
- MIDI export with midilib
- Plugin hooks around layout and rendering

## Installation

Clef requires Ruby 3.1 or newer.

For local development:

```bash
git clone https://github.com/ydah/clef.git
cd clef
bin/setup
```

For PDF output with SMuFL glyphs, place `Bravura.otf` at `fonts/bravura/Bravura.otf`.
If the font file is missing, Clef falls back to `Helvetica`.

## Quick Start

```ruby
require "clef"

score = Clef.score do
  title "Twinkle Twinkle Little Star"
  composer "Traditional"
  tempo beat_unit: :quarter, bpm: 100

  staff :melody, clef: :treble do
    key :c, :major
    time 4, 4
    play "c'4 c'4 g'4 g'4 | a'4 a'4 g'2 | f'4 f'4 e'4 e'4 | d'4 d'4 c'2"
  end
end

score.to_pdf("twinkle.pdf")
score.to_svg("twinkle.svg")
score.to_midi("twinkle.mid")
```

`title`, `composer`, and `tempo` are stored on the score. The current PDF and SVG renderers focus on staff content, while `tempo` is also used by MIDI export.

## DSL Overview

Clef's main entry point is `Clef.score`.

- `staff` creates a staff
- `staff_group(:brace)` and `staff_group(:bracket)` group staves in the score model
- `play` splits measures on `|`
- `play` and `notes` accept LilyPond-like tokens such as `c'4`, `r8`, and `<c' e' g'>2.`
- `voice` gives explicit control over notes, rests, and chords
- `lyrics` attaches lyric data to a named voice

Example:

```ruby
score = Clef.score do
  staff_group :brace do
    staff :piano_rh, clef: :treble do
      key :c, :major
      time 4, 4
      play "c'4 e'4 g'4 c''4"
    end

    staff :piano_lh, clef: :bass do
      key :c, :major
      time 4, 4

      voice :main do
        chord %w[c3 g3], :half
        rest :half
      end
    end
  end
end
```

Within a `voice` block, manual builders accept scientific pitch strings such as `C4`, `F#3`, and `Bb5`. The shorthand token parser used by `play` and `notes` expects LilyPond-style pitch tokens.

## LilyPond Input

`Clef::Parser::LilypondParser` supports a small subset of LilyPond and turns it into a `Clef::Core::Score`.

```ruby
parser = Clef::Parser::LilypondParser.new

score = parser.parse(<<~LY)
  \clef treble
  \key c \major
  \time 4/4
  { c'4 d'4 e'4 f'4 }
LY

score.to_svg("phrase.svg")
```

The current parser recognizes:

- `\clef`
- `\key` with `\major` or `\minor`
- `\time`
- Note, rest, chord, and bar tokens inside `{ ... }`

## Plugins

Clef exposes plugin hooks through `Clef.plugins`.

```ruby
class MarkerPlugin < Clef::Plugins::Base
  def on_before_layout(score)
    score.metadata[:prepared] = true
  end
end

Clef.plugins.register(MarkerPlugin)
```

Available hooks:

- `on_before_layout(score)`
- `on_after_layout(layout_result)`
- `on_before_render(renderer)`

## Current Scope

- PDF and SVG rendering currently cover clefs, key and time metadata, noteheads, rests, stems, accidentals, dots, chords, and simple articulation text.
- PDF and SVG do not yet render score headers, lyric lines, ties, slurs, beams, or staff-group braces and brackets.
- PDF, SVG, and MIDI export currently consume the first voice in each measure. The core model and IR can hold multiple voices, but full polyphonic engraving and playback are not wired into the output pipeline yet.
- The compiler currently computes `Clef::Ir::MusicTree` and `Clef::Layout::Spacing` before rendering. `Clef::Layout::LineBreaker`, `PageBreaker`, and `BeamLayout` exist in the codebase as standalone building blocks and are covered by specs, but they are not yet integrated into PDF or SVG output.

## Development

Install dependencies:

```bash
bin/setup
```

Run the test suite:

```bash
bundle exec rspec
bundle exec rake
```

Run an example:

```bash
bundle exec ruby examples/twinkle.rb
```

Open a console:

```bash
bin/console
```

## License

MIT License.
