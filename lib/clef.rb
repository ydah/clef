# frozen_string_literal: true

require_relative "clef/version"
require_relative "clef/core/duration"
require_relative "clef/core/pitch"
require_relative "clef/core/time_signature"
require_relative "clef/core/tempo"
require_relative "clef/core/clef"
require_relative "clef/core/key_signature"
require_relative "clef/core/note"
require_relative "clef/core/rest"
require_relative "clef/core/chord"
require_relative "clef/core/tuplet"
require_relative "clef/core/voice"
require_relative "clef/core/measure"
require_relative "clef/core/metadata"
require_relative "clef/core/staff"
require_relative "clef/core/staff_group"
require_relative "clef/core/validation"
require_relative "clef/core/score"
require_relative "clef/notation/articulation"
require_relative "clef/notation/barline"
require_relative "clef/notation/beam"
require_relative "clef/notation/dynamic"
require_relative "clef/notation/lyric"
require_relative "clef/notation/slur"
require_relative "clef/notation/tie"
require_relative "clef/engraving/rules"
require_relative "clef/engraving/style"
require_relative "clef/engraving/glyph_table"
require_relative "clef/engraving/font_manager"
require_relative "clef/ir/moment"
require_relative "clef/ir/event"
require_relative "clef/ir/timeline"
require_relative "clef/ir/music_tree"
require_relative "clef/layout/beam_layout"
require_relative "clef/layout/item"
require_relative "clef/layout/line_breaker"
require_relative "clef/layout/page_breaker"
require_relative "clef/layout/spacing"
require_relative "clef/layout/stem"
require_relative "clef/layout/system_layout"
require_relative "clef/plugins/base"
require_relative "clef/plugins/registry"
require_relative "clef/renderer/base"
require_relative "clef/renderer/drawing_context"
require_relative "clef/renderer/notation_helpers"
require_relative "clef/renderer/pdf_renderer"
require_relative "clef/renderer/svg_renderer"
require_relative "clef/midi/channel_map"
require_relative "clef/midi/exporter"
require_relative "clef/parser/lilypond_lexer"
require_relative "clef/parser/dsl"
require_relative "clef/parser/lilypond_parser"
require_relative "clef/compiler"

module Clef
  class Error < StandardError; end

  class << self
    attr_reader :last_score

    # @yield DSL block
    # @return [Clef::Core::Score]
    def score(plugins: Clef.plugins, &block)
      builder = Clef::Parser::DSL::ScoreBuilder.new(plugins: plugins)
      if block
        (block.arity == 1) ? block.call(builder) : builder.instance_eval(&block)
      end
      @last_score = builder.build
    end

    # @return [Clef::Plugins::Registry]
    def plugins
      @plugins ||= Clef::Plugins::Registry.new
    end
  end
end
