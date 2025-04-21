# frozen_string_literal: true

require "tempfile"

require "rspec/core"

module Specstorm
  class ListExamples
    def initialize(dir)
      @dir = dir
    end

    def examples
      return @examples if defined?(@examples)

      @examples = []

      RSpec.configuration.files_or_directories_to_run = @dir
      RSpec::Core::Formatters.register self.class, :stop
      RSpec.configuration.add_formatter(self)

      unless RSpec::Core::Runner.new(options).run($stderr, out).zero?
        out.tap(&:rewind).each_line { |line| $stdout.print line }
      end

      @examples
    end

    # Called as the formatter
    def stop(group_notification)
      group_notification.notifications.map do |notification|
        @examples << {
          :id => notification.example.id,
          :full_description => notification.example.full_description,
          :file_path => notification.example.metadata[:file_path],
          :line_number  => notification.example.metadata[:line_number],
        }
      end
    end

    private

    def out
      @out ||= Tempfile.new.tap do |f|
        f.define_singleton_method(:tty?) { true }
      end
    end

    def options
      RSpec::Core::ConfigurationOptions.new(
        ["--dry-run", *RSpec.configuration.files_to_run]
      )
    end
  end
end
