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
- Plugin hooks around parsing, layout, rendering, glyph registration, and MIDI export

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
score.to_format("twinkle.svg")
```

`title`, `composer`, and `tempo` are stored on the score. PDF and SVG render score headers and staff content; MIDI converts the tempo beat unit into quarter-note tempo for playback.

## DSL Overview

Clef's main entry point is `Clef.score`.

- `staff` creates a staff
- `staff_group(:brace)` and `staff_group(:bracket)` group staves in the score model
- `play` splits measures on `|`
- `play` and `notes` accept LilyPond-like tokens such as `c'4`, `r8`, and `<c' e' g'>2.`
- `play` and `notes` inherit the previous duration for tokens such as `c'4 d' e' f'`
- `play` and `notes` read a small set of ties, articulations, slurs, and beam hints
- `voice` gives explicit control over notes, rests, and chords
- `dynamic` adds velocity/rendering markings such as `:p`, `:mf`, and `:f`
- voice-level `tempo` adds playback and rendering tempo changes
- `instrument 40` stores a staff-level MIDI program when no exporter override is provided
- `tuplet(actual, normal)` groups notes with scaled duration
- `measure` and `bar` give explicit measure control in manual DSL
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
Rests support visible, invisible, spacer, and multi-measure forms through `rest :whole, kind: :multi_measure, measures: 4`.

`to_pdf`, `to_svg`, and `to_midi` accept a filesystem path or an IO-like object responding to `write`.

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
- `\tempo`
- a small `\relative` subset
- `\new Staff`, `\new StaffGroup`, and simple simultaneous voices
- Note, rest, chord, dynamic, and bar tokens inside `{ ... }`

Unsupported commands are recorded in `parser.warnings`.

## Plugins

Clef exposes plugin hooks through `Clef.plugins`.

```ruby
class MarkerPlugin < Clef::Plugins::Base
  def on_before_layout(score)
    score.set_metadata(:prepared, true)
  end
end

Clef.plugins.register(MarkerPlugin)
```

Available hooks:

- `on_before_layout(score)`
- `on_after_layout(layout_result)`
- `on_before_render(renderer)`
- `on_after_render(path)`
- `on_after_parse(score)`
- `on_before_midi(exporter)`
- `register_glyphs(glyph_table)`

Registries support `register`, `unregister`, `clear`, plugin instances, initializer arguments, priorities, and `:raise`, `:warn`, or `:collect` hook error policies.

## Current Scope

- PDF and SVG rendering cover score headers, clefs, key and time metadata, tempo changes, dynamics, noteheads, rests, stems, flags, simple beams, accidentals, natural signs, dots, chords, articulations, lyrics, ties, slurs, and staff-group braces/brackets.
- PDF, SVG, and MIDI consume all voices in each measure. Engraving is intentionally lightweight and suited to small scores rather than full publishing-grade polyphony.
- The compiler computes `Clef::Ir::MusicTree`, spacing, line breaks, page breaks, and beam groups before rendering.
- Validation reports measure overflow errors, underfull warnings, lyric/note count mismatches, duplicate IDs, and MIDI pitch range errors.

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

The default `rake` task runs specs with SimpleCov, Standard Ruby lint, Ruby syntax checks, and a gem build smoke test.

Run an example:

```bash
bundle exec ruby examples/twinkle.rb
```

Open a console:

```bash
bin/console
```

Run the minimal executable on a Ruby file that calls `Clef.score`; the CLI exports the last score built:

```bash
bundle exec ruby exe/clef path/to/score.rb score.svg
```

## License

MIT License.
