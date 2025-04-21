# frozen_string_literal: true

require "specstorm/forked_process"

module Specstorm
  class Supervisor
    attr_reader :processes

    def initialize
      @processes = []
      @interrupted = false
      @supervisor_pid = Process.pid

      $stdout.sync = true
      $stderr.sync = true

      Signal.trap("INT") do
        if Process.pid == @supervisor_pid
          puts "Parent #{Process.pid} received SIGINT, forwarding to children..."
          interrupt!
        end
      end
    end

    def spawn(infrastructure = false, &blk)
      forked_process = ForkedProcess.fork(&blk)
      forked_process.infrastructure = infrastructure

      @processes << forked_process

      forked_process
    end

    def wait
      @log_thread = Thread.new do
        loop do
          processes.each(&:flush_pipes)
          Thread.pass
        end
      end

      while active?
        if infrastructure_process_missing?
          puts
          puts "We lost an infrastructure process. Exiting..."
          # Something went wrong, let's out put everything even if we aren't vebose
          processes.each do |process|
            process.stdout = $stdout
            process.stderr = $stderr
          end

          running_processes.each(&:kill) # forces the next interrupt to be a TERM
          interrupt!

          break
        elsif only_infrastructure_processes_remain?
          puts
          interrupt!
          puts "Only infrastructure processes remain. Exiting..."

          break
        end

        Thread.pass
      end

      puts "Our work here is done. Bye!"
    end

    def interrupt!
      @interrupted = true

      if @log_thread
        @log_thread.kill
        @log_thread.join
      end

      running_processes.each(&:kill)

      processes.each(&:flush_pipes) until running_processes.length.zero?
      processes.each(&:flush_pipes) # Once last flush for good measure
    end

    def interrupted?
      @interrupted
    end

    def active?
      !interrupted? && running_processes.length.positive?
    end

    def only_infrastructure_processes_remain?
      running_infrastructure_processes.length.positive? && running_infrastructure_processes == running_processes
    end

    def infrastructure_process_missing?
      (infrastructure_processes - running_infrastructure_processes).length.positive?
    end

    def running_processes
      processes.select(&:running?)
    end

    def running_infrastructure_processes
      infrastructure_processes.select(&:running?)
    end

    def infrastructure_processes
      processes.select(&:infrastructure?)
    end
  end
end
