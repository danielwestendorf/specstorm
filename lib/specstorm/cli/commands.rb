require "dry/cli"
require "specstorm/wrk"
require "specstorm/srv"

module Specstorm
  module CLI
    module Commands
      extend Dry::CLI::Registry

      class Version < Dry::CLI::Command
        desc "Print version"

        def call(*)
          puts VERSION
        end
      end

      module Workable
        def self.included(base)
          base.option :duration, type: :integer, default: 10, aliases: ["-d"], desc: "Simulate work for this long"
        end
      end

      class Work < Dry::CLI::Command
        include Workable

        desc "Start a worker"

        def call(duration:, **)
          Specstorm::Wrk.run(duration: duration.to_i)
        end
      end

      module Servable
        def self.included(base)
          base.option :port, type: :integer, default: 5138, aliases: ["-p"], desc: "Server port"
        end
      end

      class Serve < Dry::CLI::Command
        include Servable

        desc "Start a server"

        def call(port:, **)
          Specstorm::Srv.serve(port: port.to_i)
        end
      end

      class Start < Dry::CLI::Command
        include Workable
        include Servable

        desc "Start a server and worker"

        def call(duration:, port:, **)
          Specstorm::Wrk.run(duration: duration.to_i)
          Specstorm::Srv.serve(port: port.to_i)
        end
      end

      register "version", Version, aliases: ["v", "-v", "--version"]
      register "work", Work, aliases: ["wrk", "twerk", "w"]
      register "serve", Serve, aliases: ["srv", "s"]
      register "start", Start
    end
  end
end
