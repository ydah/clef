# frozen_string_literal: true

module Clef
  module Core
    class Score
      attr_reader :staff_groups, :metadata
      attr_accessor :title, :composer, :tempo, :plugins

      # @param metadata [Hash]
      def initialize(metadata: {})
        @staff_groups = []
        @metadata = metadata.dup
      end

      # @param value [Hash]
      def metadata=(value)
        raise ArgumentError, "metadata must be a Hash" unless value.is_a?(Hash)

        @metadata = value.dup
      end

      # @param staff_group [StaffGroup]
      # @return [Score]
      def add_staff_group(staff_group)
        raise ArgumentError, "staff_group must be a Clef::Core::StaffGroup" unless staff_group.is_a?(StaffGroup)
        duplicate = staff_group.staves.find { |staff| staves.any? { |existing| existing.id == staff.id } }
        raise ArgumentError, "duplicate staff id: #{duplicate.id}" if duplicate

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

      # @param path [String, #write]
      # @param options [Hash]
      def to_midi(path, **options)
        ::Clef::Midi::Exporter.new(self, **options).export(path)
      end

      # @param path [String]
      # @param options [Hash]
      def to_format(path, **options)
        case File.extname(path.to_s).downcase
        when ".pdf" then to_pdf(path, **options)
        when ".svg" then to_svg(path, **options)
        when ".mid", ".midi" then to_midi(path, **options)
        else
          raise ArgumentError, "unsupported output format for #{path.inspect}"
        end
      end

      # @param strict [Boolean]
      # @return [ValidationResult]
      def validate(strict: false)
        result = ValidationResult.new(validation_issues)
        raise Clef::Error, result.errors.map(&:message).join(", ") if strict && !result.ok?

        result
      end

      # @return [Array<ValidationIssue>]
      def validation_warnings
        validate.warnings
      end

      private

      def validation_issues
        staff_issues + measure_issues + lyric_issues + pitch_issues
      end

      def staff_issues
        staves.map(&:id).tally.filter_map do |id, count|
          next unless count > 1

          ValidationIssue.new(severity: :error, message: "duplicate staff id: #{id}", path: [:score, :staves, id])
        end
      end

      def measure_issues
        staves.flat_map do |staff|
          staff.measures.flat_map do |measure|
            overflow_issues(staff, measure) + underfull_issues(staff, measure)
          end
        end
      end

      def overflow_issues(staff, measure)
        measure.overflowing_voice_ids.map do |voice_id|
          ValidationIssue.new(
            severity: :error,
            message: "measure #{measure.number} voice #{voice_id} exceeds time signature length",
            path: [:staff, staff.id, :measure, measure.number, :voice, voice_id]
          )
        end
      end

      def underfull_issues(staff, measure)
        measure.underfull_voice_ids.map do |voice_id|
          ValidationIssue.new(
            severity: :warning,
            message: "measure #{measure.number} voice #{voice_id} is shorter than time signature length",
            path: [:staff, staff.id, :measure, measure.number, :voice, voice_id]
          )
        end
      end

      def lyric_issues
        staves.flat_map do |staff|
          Array(staff.metadata[:lyrics]).flat_map do |lyric|
            note_count = staff.measures.sum do |measure|
              Array(measure.voices[lyric.voice_id]&.elements).count { |element| element.is_a?(Note) }
            end
            next [] if lyric.syllables.length == note_count

            [
              ValidationIssue.new(
                severity: :warning,
                message: "lyrics for voice #{lyric.voice_id} have #{lyric.syllables.length} syllables for #{note_count} notes",
                path: [:staff, staff.id, :lyrics, lyric.voice_id]
              )
            ]
          end
        end
      end

      def pitch_issues
        staves.flat_map do |staff|
          staff.measures.flat_map do |measure|
            measure.voices.flat_map do |voice_id, voice|
              voice.elements.flat_map { |element| invalid_pitch_issues(element, staff.id, measure.number, voice_id) }
            end
          end
        end
      end

      def invalid_pitch_issues(element, staff_id, measure_number, voice_id)
        pitches_for(element).filter_map do |pitch|
          pitch.to_midi
          nil
        rescue RangeError => e
          ValidationIssue.new(
            severity: :error,
            message: e.message,
            path: [:staff, staff_id, :measure, measure_number, :voice, voice_id]
          )
        end
      end

      def pitches_for(element)
        case element
        when Note then [element.pitch]
        when Chord then element.pitches
        when Tuplet then element.elements.flat_map { |child| pitches_for(child) }
        else []
        end
      end

      def default_group
        staff_groups.first || add_staff_group(StaffGroup.new)
        staff_groups.first
      end
    end
  end
end
