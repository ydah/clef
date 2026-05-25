# frozen_string_literal: true

module Clef
  module Layout
    class Stem
      class << self
        # @param note_or_notes [Clef::Core::Note, Array<Clef::Core::Note>]
        # @param clef [Clef::Core::Clef]
        # @return [Symbol]
        def direction(note_or_notes, clef)
          notes = Array(note_or_notes)
          middle = diatonic_step(clef.reference_pitch)
          down_votes = notes.count { |note| diatonic_step(note.pitch) > middle }
          (down_votes > (notes.length / 2.0)) ? :down : :up
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

        def diatonic_step(pitch)
          note_index = Clef::Core::Pitch::VALID_NOTE_NAMES.index(pitch.note_name)
          (pitch.octave * 7) + note_index
        end

        def ledger_extension(pitch)
          return 1.5 if pitch.to_midi > 84
          return 1.5 if pitch.to_midi < 48

          0.0
        end
      end
    end
  end
end
