# Clef

[![Ruby](https://github.com/ydah/clef/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/ydah/clef/actions/workflows/main.yml)
[![Gem Version](https://img.shields.io/gem/v/clef.svg)](https://rubygems.org/gems/clef)
[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%203.1-red.svg)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

Clef is a lightweight Ruby toolkit for building small music scores, parsing a practical LilyPond-style syntax subset, and exporting PDF, SVG, or MIDI.

It is intended for concise notation workflows, examples, and application embedding. It is not a full replacement for LilyPond, MusicXML, or a publishing-grade engraving engine.

## Requirements

- Ruby 3.1 or newer
- Bundler for development
- Optional: `fonts/bravura/Bravura.otf` for higher quality PDF/SVG music glyphs

## Installation

Add Clef to your application's Gemfile:

```ruby
gem "clef"
```

For local development:

```sh
git clone https://github.com/ydah/clef.git
cd clef
bin/setup
```

## Quick Start

```ruby
require "clef"

score = Clef.score do
  title "Twinkle Twinkle Little Star"
  composer "Traditional"

  staff :piano, clef: :treble do
    key :c, :major
    time 4, 4

    play "c'4 c'4 g'4 g'4 | a'4 a'4 g'2 | f'4 f'4 e'4 e'4 | d'4 d'4 c'2"
  end
end

score.to_pdf("twinkle.pdf")
score.to_svg("twinkle.svg")
score.to_midi("twinkle.mid")
```

`score.to_format("twinkle.svg")` chooses PDF, SVG, or MIDI from the file extension.

## DSL Essentials

Use `Clef.score` with one or more `staff` blocks. Inside a staff you can set notation state and add music with `play`:

```ruby
score = Clef.score do
  title "Example"
  tempo beat_unit: :quarter, bpm: 96

  staff :violin, clef: :treble do
    key :d, :major
    time 3, 4
    instrument 40

    play "fis'4 g'4 a'4"
    lyrics :default, "one two three"
  end
end
```

Common `play` tokens:

- Notes: `c'4`, `fis'8`, `bes2`
- Rests: `r4`, `r8`
- Chords: `<c' e' g'>2`
- Durations: `1`, `2`, `4`, `8`, `16`, with dotted values such as `4.`
- Measure separators: `|`
- Ties, slurs, articulations, and dynamics are supported in the lightweight DSL subset

For multi-part scores, use multiple `staff` blocks or `staff_group`:

```ruby
score = Clef.score do
  title "Piano Sketch"

  staff_group :brace do
    staff :right, clef: :treble do
      key :c, :major
      time 4, 4
      play "c''4 e''4 g''4 c'''4"
    end

    staff :left, clef: :bass do
      key :c, :major
      time 4, 4
      play "c2 g,2"
    end
  end
end
```

## LilyPond-Style Input

Clef can parse a practical subset of LilyPond-style input:

```ruby
parser = Clef::Parser::LilypondParser.new
score = parser.parse(<<~'LILYPOND')
  \tempo 4 = 96
  \new Staff {
    \clef treble
    \key c \major
    \time 4/4
    { c'4 d'4 e'4 f'4 | }
  }
LILYPOND

warn parser.warnings.join("\n") unless parser.warnings.empty?
```

The importer supports tempo, staves, staff groups, clefs, key and time signatures, notes, rests, chords, a small relative pitch subset, simultaneous voices, dynamics, articulations, ties, slurs, beams, and measure splitting. Unsupported commands are skipped and reported as warnings with source locations.

## Plugins

Plugins can inspect or modify scores before rendering, and can observe rendering lifecycle events:

```ruby
class PreparedFlagPlugin < Clef::Plugins::Base
  def on_before_layout(score)
    score.set_metadata(:prepared, true)
  end
end

Clef.plugins.register(PreparedFlagPlugin)
```

Common hooks are `on_before_layout`, `on_after_layout`, `on_before_render`, `on_after_render`, `on_after_parse`, `on_before_midi`, and `register_glyphs`.

## Development

```sh
bin/setup
bundle exec rake
bundle exec ruby examples/twinkle.rb
bundle exec ruby exe/clef examples/twinkle.rb twinkle.svg
```

`bundle exec rake` runs specs, lint, syntax checks, and a gem build smoke test.

## License

Clef is available as open source under the terms of the MIT License.
