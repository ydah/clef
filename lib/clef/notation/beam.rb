# frozen_string_literal: true

module Clef
  module Notation
    class Beam
      attr_reader :notes

      # @param notes [Array<Clef::Core::Note>]
      def initialize(notes)
        raise ArgumentError, "beam requires at least two notes" if notes.length < 2

        @notes = notes
      end

      # @return [Integer]
      def level
        shortest = notes.map { |note| note.duration.base_value }.min
        return 1 if shortest >= Rational(1, 8)
        return 2 if shortest >= Rational(1, 16)

        3
      end
    end
  end
end
