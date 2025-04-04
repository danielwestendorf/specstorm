# frozen_string_literal: true

require "dry/cli"

require "specstorm/supervisor"

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
          base.option :worker_processes, type: :integer, default: Etc.nprocessors, aliases: ["-n", "--number"], desc: "Number of workers"
          base.option :duration, type: :integer, default: 10, aliases: ["-d"], desc: "Simulate work for this long"
        end

        def spawn_workers(duration:, worker_processes:)
          [1, worker_processes.to_i].max.times do
            spawn_worker(duration: duration)
          end
        end

        def spawn_worker(duration:)
          @count ||= -1
          @count += 1

          supervisor.spawn do
            ENV["SPECSTORM_PROCESS"] = @count.to_s
            Specstorm::Wrk.run(duration: duration.to_i)
          end
        end

        def supervisor
          @supervisor ||= Supervisor.new
        end
      end

      class Work < Dry::CLI::Command
        include Workable

        desc "Start a worker"

        def call(duration:, worker_processes:, **args)
          spawn_workers(duration: duration, worker_processes: worker_processes)
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
          Specstorm::Srv.serve(port: port.to_i)
        end
      end

      class Start < Dry::CLI::Command
        include Workable
        include Servable

        desc "Start a server and worker"

        def call(duration:, port:, worker_processes:, **)
          supervisor.spawn(true) { Specstorm::Srv.serve(port: port.to_i) }

          spawn_workers(duration: duration, worker_processes: worker_processes)

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
