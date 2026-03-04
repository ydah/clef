# frozen_string_literal: true

module Clef
  module Core
    class Measure
      attr_reader :number, :voices
      attr_accessor :key_signature, :time_signature, :clef

      # @param number [Integer]
      # @param time_signature [TimeSignature, nil]
      def initialize(number, time_signature: nil)
        raise ArgumentError, "measure number must be positive" unless number.is_a?(Integer) && number.positive?

        @number = number
        @time_signature = time_signature
        @voices = {}
      end

      # @param id [Symbol]
      # @yield [Voice]
      # @return [Voice]
      def voice(id = :default)
        current = voices[id] ||= Voice.new(id: id)
        yield(current) if block_given?
        warn_overflow_if_needed(id, current)
        current
      end

      # @return [Array<Symbol>]
      def overflowing_voice_ids
        return [] unless time_signature

        voices.filter_map { |id, voice| id if voice.total_length > time_signature.measure_length }
      end

      private

      def warn_overflow_if_needed(id, voice)
        return unless time_signature
        return unless voice.total_length > time_signature.measure_length

        warn("Measure #{number} voice #{id} exceeds time signature length")
      end
    end
  end
end
