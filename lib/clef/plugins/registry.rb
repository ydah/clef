# frozen_string_literal: true

module Clef
  module Plugins
    class Registry
      ERROR_POLICIES = %i[raise warn collect].freeze

      attr_reader :errors

      # @param error_policy [Symbol]
      def initialize(error_policy: :raise)
        raise ArgumentError, "unsupported hook error policy" unless ERROR_POLICIES.include?(error_policy)

        @entries = []
        @next_order = 0
        @error_policy = error_policy
        @errors = []
      end

      # @return [Array<Plugins::Base>]
      def plugins
        @entries.map { |entry| entry[:plugin] }
      end

      # @param plugin_or_class [Class, Plugins::Base]
      # @param args [Array]
      # @param priority [Integer]
      # @param kwargs [Hash]
      # @return [Plugins::Base]
      def register(plugin_or_class, *args, priority: 0, **kwargs)
        plugin = build_plugin(plugin_or_class, *args, **kwargs)
        @entries << {plugin: plugin, priority: priority, order: @next_order}
        @next_order += 1
        @entries.sort_by! { |entry| [entry[:priority], entry[:order]] }
        plugin
      end

      # @param plugin_or_class [Class, Plugins::Base, String, Symbol]
      # @return [Plugins::Base, nil]
      def unregister(plugin_or_class)
        entry = @entries.find { |candidate| plugin_match?(candidate[:plugin], plugin_or_class) }
        return unless entry

        @entries.delete(entry)
        entry[:plugin]
      end

      # @return [Array]
      def clear
        @entries.clear
      end

      # @param hook_name [Symbol]
      # @param args [Array<Object>]
      # @return [Array<Object>]
      def run_hook(hook_name, *args)
        plugins.each_with_object([]) do |plugin, results|
          next unless plugin.respond_to?(hook_name)

          results << run_plugin_hook(plugin, hook_name, args)
        end
      end

      private

      def build_plugin(plugin_or_class, *args, **kwargs)
        if plugin_or_class.is_a?(Class)
          raise ArgumentError, "plugin must inherit Clef::Plugins::Base" unless plugin_or_class < Base

          return plugin_or_class.new(*args, **kwargs)
        end
        return plugin_or_class if plugin_or_class.is_a?(Base)

        raise ArgumentError, "plugin must inherit Clef::Plugins::Base"
      end

      def plugin_match?(plugin, candidate)
        return plugin.equal?(candidate) if candidate.is_a?(Base)
        return plugin.is_a?(candidate) if candidate.is_a?(Class)

        plugin.class.plugin_name.to_s == candidate.to_s
      end

      def run_plugin_hook(plugin, hook_name, args)
        plugin.public_send(hook_name, *args)
      rescue => e
        handle_hook_error(plugin, hook_name, e)
      end

      def handle_hook_error(plugin, hook_name, error)
        case @error_policy
        when :raise
          raise error
        when :warn
          warn("Clef plugin #{plugin.class.plugin_name} #{hook_name} failed: #{error.message}")
          nil
        when :collect
          errors << {plugin: plugin, hook: hook_name, error: error}
          nil
        end
      end
    end
  end
end
