# frozen_string_literal: true

require "etc"
require "dry/cli"

require "specstorm/supervisor"

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
          base.option :worker_processes, type: :integer, default: Etc.nprocessors, aliases: ["-n", "--number"], desc: "Number of workers"
        end

        def spawn_workers(worker_processes:)
          [1, worker_processes.to_i].max.times do
            spawn_worker
          end
        end

        def spawn_worker
          require "specstorm/wrk"

          supervisor.spawn do
            ENV["SPECSTORM_PROCESS"] = @count.to_s
            Specstorm::Wrk.run
          end

          @count ||= 0
          @count += 1
        end

        def supervisor
          @supervisor ||= Supervisor.new
        end
      end

      class Work < Dry::CLI::Command
        include Workable

        desc "Start a worker"

        def call(worker_processes:, **args)
          spawn_workers(worker_processes: worker_processes)
          supervisor.wait
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
          require "specstorm/srv"

          Specstorm::Srv.serve(port: port.to_i)
        end
      end

      class Start < Dry::CLI::Command
        include Workable
        include Servable

        option :verbose, type: :boolean, default: false, aliases: ["-vv"], desc: "Verbose output"

        argument :dir, required: true, default: "spec", desc: "Relative spec directory to run against"

        desc "Start a server and worker"

        def call(port:, worker_processes:, verbose:, dir:, **)
          require "specstorm/srv"
          require "specstorm/list_examples"
          require "specstorm/wrk/client"

          path = File.expand_path(dir, Dir.pwd)

          supervisor.spawn(true) do
            Specstorm::Srv.seed(examples: Specstorm::ListExamples.new(path).examples)

            Specstorm::Srv.serve(port: port.to_i, verbose: verbose)
          end

          sleep(0.1) until Specstorm::Wrk::Client.connect?

          spawn_workers(worker_processes: worker_processes)

          supervisor.wait
        end
      end

      register "version", Version, aliases: ["v", "-v", "--version"]
      register "work", Work, aliases: ["wrk", "twerk", "w"]
      register "serve", Serve, aliases: ["srv", "s"]
      register "start", Start
    end
  end
end
