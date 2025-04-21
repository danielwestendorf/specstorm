# frozen_string_literal: true

require_relative "wrk/errors"
require_relative "wrk/client"
require_relative "wrk/progress_formatter"

module Specstorm
  module Wrk
    def self.run
      client = Client.new

      loop do
        execute(client.fetch_examples)
        reset_rspec!
        flush
      rescue NoMoreExamplesError
        break
      end

      client.close
    end

    def self.execute(examples)
      RSpec.configuration.add_formatter(ProgressFormatter)
      RSpec.configuration.silence_filter_announcements = true

      options = RSpec::Core::ConfigurationOptions.new(
        ["--format", "Specstorm::Wrk::ProgressFormatter", *examples.map { |example| example[:id] }]
      )

      RSpec::Core::Runner.new(options).run($stderr, $stdout)
    end

    # https://github.com/skroutz/rspecq/blob/341383ce3ca25f42fad5483cbb6a00ba1c405570/lib/rspecq/worker.rb#L208-L224
    def self.reset_rspec!
      RSpec.clear_examples

      # see https://github.com/rspec/rspec-core/pull/2723
      if Gem::Version.new(RSpec::Core::Version::STRING) <= Gem::Version.new("3.9.1")
        RSpec.world.instance_variable_set(
          :@example_group_counts_by_spec_file, Hash.new(0)
        )
      end

      # RSpec.clear_examples does not reset those, which causes issues when
      # a non-example error occurs (subsequent jobs are not executed)
      RSpec.world.non_example_failure = false

      # we don't want an error that occured outside of the examples (which
      # would set this to `true`) to stop the worker
      RSpec.world.wants_to_quit = false
    end

    def self.flush
      print ENV["SPECSTORM_FLUSH_DELIMINATOR"] if ENV["SPECSTORM_FLUSH_DELIMINATOR"]
    end
  end
end
