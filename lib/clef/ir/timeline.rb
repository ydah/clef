# frozen_string_literal: true

module Clef
  module Ir
    class Timeline
      include Enumerable

      attr_reader :events

      def initialize
        @events = []
      end

      # @param event [Event]
      # @return [Timeline]
      def add(event)
        raise ArgumentError, "event must be a Clef::Ir::Event" unless event.is_a?(Event)

        events << event
        self
      end

      # @return [Timeline]
      def sort!
        events.sort_by! { |item| item.moment.value }
        self
      end

      # @param moment [Moment, Rational, Integer]
      # @return [Array<Event>]
      def events_at(moment)
        target = moment_value(moment)
        sorted_events.select { |event| event.moment.value == target }
      end

      # @param from [Moment, Rational, Integer]
      # @param to [Moment, Rational, Integer]
      # @return [Array<Event>]
      def events_between(from, to)
        lower = moment_value(from)
        upper = moment_value(to)
        sorted_events.select { |event| (lower..upper).cover?(event.moment.value) }
      end

      # @param from [Moment, Rational, Integer]
      # @param to [Moment, Rational, Integer]
      # @return [Array<Event>]
      def events_in_range(from, to)
        lower = moment_value(from)
        upper = moment_value(to)
        sorted_events.select { |event| event.moment.value >= lower && event.moment.value < upper }
      end

      # @yield [Moment]
      # @return [Enumerator]
      def each_moment
        return enum_for(:each_moment) unless block_given?

        unique_moments.each { |moment| yield(moment) }
      end

      def each(&block)
        sorted_events.each(&block)
      end

      # @return [Rational]
      def shortest_duration
        durations = events.filter_map { |event| event.element.length if event.element.respond_to?(:length) }
        durations.min || Rational(1, 4)
      end

      private

      def unique_moments
        sorted_events.map(&:moment).uniq
      end

      def sorted_events
        events.sort_by { |item| item.moment.value }
      end

      def moment_value(value)
        value.is_a?(Moment) ? value.value : Rational(value)
      end
    end
  end
end
