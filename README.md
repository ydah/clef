# Clef

Clef is a Ruby gem for score modeling and engraving.

It provides:
- Core music domain objects (`Pitch`, `Duration`, `Note`, `Score`)
- Ruby DSL for writing music textually
- Rendering pipeline for PDF and SVG output
- Basic LilyPond parsing and MIDI export
- Plugin hooks for custom behaviors

## Installation

```bash
bundle add clef
```

## Quick Start

```ruby
require "clef"

score = Clef.score do
  title "Twinkle Twinkle"
  composer "Traditional"
  tempo beat_unit: :quarter, bpm: 100

  staff :melody, clef: :treble do
    key :c, :major
    time 4, 4
    play "c'4 c'4 g'4 g'4 | a'4 a'4 g'2"
  end
end

score.to_pdf("twinkle.pdf")
score.to_svg("twinkle.svg")
score.to_midi("twinkle.mid")
```

## DSL Reference (Core)

```ruby
Clef.score do
  title "Example"
  composer "Composer"

  staff :violin, name: "Violin", clef: :treble do
    key :g, :major
    time 4, 4

    voice :main do
      note "c4", :quarter
      rest :eighth
      chord ["c4", "e4", "g4"], :quarter, articulations: [:accent]
      notes "d'8 e'8 f'4"
    end

    play "g'4 a'4 b'4 c''4"
    lyrics :main, "la-la la"
  end
end
```

## Architecture Overview

Pipeline:
1. DSL / Parser input
2. Score domain model
3. Timeline IR (`Clef::Ir::MusicTree`)
4. Layout (`Spacing`, `LineBreaker`, `PageBreaker`)
5. Renderer (`PdfRenderer` / `SvgRenderer`)

## Development

```bash
bundle install
bundle exec rspec
```

Run examples:

```bash
bundle exec ruby examples/twinkle.rb
```

## License

MIT License.
