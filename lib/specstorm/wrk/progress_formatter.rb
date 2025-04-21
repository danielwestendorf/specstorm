# frozen_string_literal: true

RSpec::Support.require_rspec_core "formatters/base_text_formatter"
RSpec::Support.require_rspec_core "formatters/console_codes"

module Specstorm
  module Wrk
    class ProgressFormatter
      RSpec::Core::Formatters.register self, :example_passed, :example_pending, :example_failed

      attr_reader :output

      def initialize(output)
        @output = output
      end

      def example_passed(_notification)
        output.print RSpec::Core::Formatters::ConsoleCodes.wrap(".", :success)
      end

      def example_pending(_notification)
        output.print RSpec::Core::Formatters::ConsoleCodes.wrap("*", :pending)
      end

      def example_failed(_notification)
        output.print RSpec::Core::Formatters::ConsoleCodes.wrap("F", :failure)
      end
    end
  end
end
