# frozen_string_literal: true

module Clef
  module Core
    class Score
      attr_reader :staff_groups, :metadata
      attr_accessor :title, :composer, :tempo

      # @param metadata [Hash]
      def initialize(metadata: {})
        @staff_groups = []
        @metadata = metadata
      end

      # @param staff_group [StaffGroup]
      # @return [Score]
      def add_staff_group(staff_group)
        raise ArgumentError, "staff_group must be a Clef::Core::StaffGroup" unless staff_group.is_a?(StaffGroup)

        staff_groups << staff_group
        self
      end

      # @param staff [Staff]
      # @return [Score]
      def add_staff(staff)
        default_group.add_staff(staff)
        self
      end

      # @return [Array<Staff>]
      def staves
        staff_groups.flat_map(&:staves)
      end

      # @param path [String]
      # @param options [Hash]
      def to_pdf(path, **options)
        ::Clef::Compiler.new(self, **options).compile_to_pdf(path)
      end

      # @param path [String]
      # @param options [Hash]
      def to_svg(path, **options)
        ::Clef::Compiler.new(self, **options).compile_to_svg(path)
      end

      # @param path [String]
      def to_midi(path, **_options)
        ::Clef::Midi::Exporter.new(self).export(path)
      end

      private

      def default_group
        staff_groups.first || add_staff_group(StaffGroup.new)
        staff_groups.first
      end
    end
  end
end
