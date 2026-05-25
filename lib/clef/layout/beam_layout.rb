# frozen_string_literal: true

module Clef
  module Layout
    class BeamLayout
      class << self
        # @param notes [Array<Clef::Core::Note>]
        # @param time_signature [Clef::Core::TimeSignature]
        # @return [Array<Array<Clef::Core::Note>>]
        def auto_beam(notes, time_signature)
          return [] if notes.empty?

          notes.each_slice(group_size(time_signature)).to_a
        end

        # @param beam_group [Array<Clef::Core::Note>]
        # @param _clef [Clef::Core::Clef]
        # @param _spacing [Hash]
        # @return [Hash]
        def compute(beam_group, _clef, _spacing)
          first_y = pitch_y(beam_group.first.pitch)
          last_y = pitch_y(beam_group.last.pitch)
          slope = ((last_y - first_y) / [beam_group.length - 1, 1].max).clamp(-0.5, 0.5)
          {start_y: first_y, end_y: first_y + slope * (beam_group.length - 1), slope: slope}
        end

        private

        def group_size(time_signature)
          return 3 if time_signature.denominator == 8 && (time_signature.numerator % 3).zero?
          return 4 if time_signature.denominator == 4 && time_signature.numerator == 4

          [time_signature.numerator, 2].max
        end

        def pitch_y(pitch)
          pitch.to_midi.to_f / 12.0
        end
      end
    end
  end
end
