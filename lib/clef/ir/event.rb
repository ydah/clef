# frozen_string_literal: true

module Clef
  module Ir
    class Event
      attr_reader :moment, :element, :staff_id, :voice_id

      # @param moment [Moment]
      # @param element [Object]
      # @param staff_id [Symbol, String, nil]
      # @param voice_id [Symbol, String, nil]
      def initialize(moment:, element:, staff_id: nil, voice_id: nil)
        raise ArgumentError, "moment must be a Clef::Ir::Moment" unless moment.is_a?(Moment)

        @moment = moment
        @element = element
        @staff_id = staff_id
        @voice_id = voice_id
      end
    end
  end
end
