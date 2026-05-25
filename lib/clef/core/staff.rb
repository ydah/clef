# frozen_string_literal: true

module Clef
  module Core
    class Staff
      attr_reader :id, :name, :clef
      attr_accessor :key_signature, :time_signature
      attr_reader :metadata

      # @param id [Symbol]
      # @param name [String, nil]
      # @param clef [Clef]
      def initialize(id, name: nil, clef: Clef.new(:treble))
        raise ArgumentError, "id must be provided" if id.nil?
        raise ArgumentError, "clef must be a Clef::Core::Clef" unless clef.is_a?(Clef)

        @id = id
        @name = name || id.to_s
        @clef = clef
        @measures = []
        @metadata = {}
      end

      # @param value [Hash]
      def metadata=(value)
        raise ArgumentError, "metadata must be a Hash" unless value.is_a?(Hash)

        @metadata = value.dup
      end

      # @param measure [Measure]
      # @return [Staff]
      def add_measure(measure)
        raise ArgumentError, "measure must be a Clef::Core::Measure" unless measure.is_a?(Measure)
        raise ArgumentError, "duplicate measure number: #{measure.number}" if @measures.any? { |item| item.number == measure.number }
        if @measures.any? && measure.number < @measures.last.number
          raise ArgumentError, "measure numbers must be added in ascending order"
        end

        @measures << measure
        self
      end

      # @return [Array<Measure>]
      def measures
        @measures.dup.freeze
      end
    end
  end
end
