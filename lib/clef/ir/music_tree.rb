# frozen_string_literal: true

module Clef
  module Ir
    class MusicTree
      class << self
        # @param score [Clef::Core::Score]
        # @return [Timeline]
        def build(score)
          timeline = Timeline.new
          score.staves.each { |staff| append_staff_events(timeline, staff) }
          timeline
        end

        private

        def append_staff_events(timeline, staff)
          current = Moment.new(0)
          staff.measures.each do |measure|
            append_measure_metadata(timeline, measure, staff, current)
            append_measure_voices(timeline, measure, staff, current)
            current = current + measure_length_for(measure)
          end
        end

        def append_measure_metadata(timeline, measure, staff, current)
          [measure.clef, measure.key_signature, measure.time_signature].compact.each do |element|
            timeline.add(Event.new(moment: current, element: element, staff_id: staff.id, voice_id: :meta))
          end
        end

        def append_measure_voices(timeline, measure, staff, current)
          measure.voices.each do |voice_id, voice|
            append_voice_events(timeline, voice, current, staff.id, voice_id)
          end
        end

        def append_voice_events(timeline, voice, start_moment, staff_id, voice_id)
          cursor = Moment.new(start_moment.value)
          voice.elements.each do |element|
            timeline.add(Event.new(moment: cursor, element: element, staff_id: staff_id, voice_id: voice_id))
            cursor = cursor + element.length
          end
        end

        def measure_length_for(measure)
          return measure.time_signature.measure_length if measure.time_signature

          measure.voices.values.map(&:total_length).max || Rational(0, 1)
        end
      end
    end
  end
end
