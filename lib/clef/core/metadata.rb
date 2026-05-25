# frozen_string_literal: true

module Clef
  module Core
    module Metadata
      # @return [Hash]
      def metadata
        immutable_metadata(@metadata)
      end

      # @param value [Hash]
      def metadata=(value)
        raise ArgumentError, "metadata must be a Hash" unless value.is_a?(Hash)

        @metadata = value.dup
      end

      # @param key [Object]
      # @param value [Object]
      # @return [self]
      def set_metadata(key, value)
        @metadata[key] = value
        self
      end

      # @param value [Hash, nil]
      # @param kwargs [Hash]
      # @return [self]
      def update_metadata(value = nil, **kwargs)
        source = value || {}
        raise ArgumentError, "metadata must be a Hash" unless source.is_a?(Hash)

        @metadata.merge!(source)
        @metadata.merge!(kwargs)
        self
      end

      private

      def immutable_metadata(value)
        case value
        when Hash
          value.to_h { |key, item| [key, immutable_metadata(item)] }.freeze
        when Array
          value.map { |item| immutable_metadata(item) }.freeze
        else
          value
        end
      end
    end
  end
end
