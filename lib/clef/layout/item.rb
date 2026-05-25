# frozen_string_literal: true

module Clef
  module Layout
    class Item
      attr_reader :type, :moment, :staff_id, :measure_number, :payload

      # @param type [Symbol]
      # @param moment [Clef::Ir::Moment]
      # @param staff_id [Symbol, String, nil]
      # @param measure_number [Integer, nil]
      # @param payload [Hash]
      def initialize(type:, moment:, staff_id: nil, measure_number: nil, payload: {})
        raise ArgumentError, "type must be a Symbol" unless type.is_a?(Symbol)
        raise ArgumentError, "moment must be a Clef::Ir::Moment" unless moment.is_a?(Clef::Ir::Moment)
        raise ArgumentError, "payload must be a Hash" unless payload.is_a?(Hash)

        @type = type
        @moment = moment
        @staff_id = staff_id
        @measure_number = measure_number
        @payload = payload.dup
      end
    end
  end
end
