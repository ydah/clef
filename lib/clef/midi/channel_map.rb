# frozen_string_literal: true

module Clef
  module Midi
    class ChannelMap
      # @param staff_index [Integer]
      # @return [Integer]
      def channel_for(staff_index)
        base = staff_index % 15
        base >= 9 ? base + 1 : base
      end
    end
  end
end
