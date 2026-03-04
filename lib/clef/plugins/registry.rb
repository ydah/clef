# frozen_string_literal: true

module Clef
  module Plugins
    class Registry
      attr_reader :plugins

      def initialize
        @plugins = []
      end

      # @param plugin_class [Class]
      # @return [Plugins::Base]
      def register(plugin_class)
        raise ArgumentError, "plugin must inherit Clef::Plugins::Base" unless plugin_class < Base

        plugin = plugin_class.new
        plugins << plugin
        plugin
      end

      # @param hook_name [Symbol]
      # @param args [Array<Object>]
      # @return [Array<Object>]
      def run_hook(hook_name, *args)
        plugins.each_with_object([]) do |plugin, results|
          next unless plugin.respond_to?(hook_name)

          results << plugin.public_send(hook_name, *args)
        end
      end
    end
  end
end
