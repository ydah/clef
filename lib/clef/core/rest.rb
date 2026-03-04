# frozen_string_literal: true

module Clef
  module Core
    class Rest
      attr_reader :duration

      # @param duration [Duration]
      def initialize(duration)
        raise ArgumentError, "duration must be a Clef::Core::Duration" unless duration.is_a?(Duration)

        @duration = duration
      end

      # @return [Rational]
      def length
        duration.length
      end
    end
  end
end
