# frozen_string_literal: true

module Clef
  module Layout
    class Stem
      B4_MIDI = 71

      class << self
        # @param note_or_notes [Clef::Core::Note, Array<Clef::Core::Note>]
        # @param _clef [Clef::Core::Clef]
        # @return [Symbol]
        def direction(note_or_notes, _clef)
          notes = Array(note_or_notes)
          down_votes = notes.count { |note| note.pitch.to_midi > B4_MIDI }
          down_votes > (notes.length / 2.0) ? :down : :up
        end

        # @param note [Clef::Core::Note]
        # @param _clef [Clef::Core::Clef]
        # @param _direction [Symbol]
        # @return [Float]
        def length(note, _clef, _direction)
          extra = ledger_extension(note.pitch)
          Clef::Engraving::Rules::STEM_LENGTH + extra
        end

        private

        def ledger_extension(pitch)
          return 1.5 if pitch.to_midi > 84
          return 1.5 if pitch.to_midi < 48

          0.0
        end
      end
    end
  end
end
