# frozen_string_literal: true

module Clef
  module Core
    class StaffGroup
      BRACKETS = %i[bracket brace none].freeze

      attr_reader :staves, :bracket_type

      # @param staves [Array<Staff>]
      # @param bracket_type [Symbol]
      def initialize(staves = [], bracket_type: :none)
        raise ArgumentError, "unsupported bracket type" unless BRACKETS.include?(bracket_type)

        @staves = []
        @bracket_type = bracket_type
        staves.each { |staff| add_staff(staff) }
      end

      # @param staff [Staff]
      # @return [StaffGroup]
      def add_staff(staff)
        raise ArgumentError, "staff must be a Clef::Core::Staff" unless staff.is_a?(Staff)
        raise ArgumentError, "duplicate staff id: #{staff.id}" if staves.any? { |item| item.id == staff.id }

        staves << staff
        self
      end
    end
  end
end
