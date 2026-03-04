# frozen_string_literal: true

require_relative "clef/version"
Dir[File.expand_path("clef/**/*.rb", __dir__)].sort.each do |file|
  require file unless file.end_with?("version.rb")
end

module Clef
  class Error < StandardError; end

  class << self
    # @yield DSL block
    # @return [Clef::Core::Score]
    def score(&block)
      builder = Clef::Parser::DSL::ScoreBuilder.new
      builder.instance_eval(&block) if block
      builder.build
    end

    # @return [Clef::Plugins::Registry]
    def plugins
      @plugins ||= Clef::Plugins::Registry.new
    end
  end
end
