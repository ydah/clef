# frozen_string_literal: true

module Clef
  module Core
    ValidationIssue = Struct.new(:severity, :message, :path, keyword_init: true) do
      def warning?
        severity == :warning
      end

      def error?
        severity == :error
      end
    end

    class ValidationResult
      attr_reader :issues

      # @param issues [Array<ValidationIssue>]
      def initialize(issues = [])
        @issues = issues
      end

      # @return [Boolean]
      def ok?
        errors.empty?
      end

      # @return [Array<ValidationIssue>]
      def errors
        issues.select(&:error?)
      end

      # @return [Array<ValidationIssue>]
      def warnings
        issues.select(&:warning?)
      end
    end
  end
end
