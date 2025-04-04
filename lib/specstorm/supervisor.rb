# frozen_string_literal: true

module Specstorm
  class Supervisor
    attr_reader :pids, :infrastructure_pids

    def initialize
      @pids = []
      @infrastructure_pids = []
      @interrupted = false
      @supervisor_pid = Process.pid

      Signal.trap("INT") do
        if Process.pid == @supervisor_pid
          puts "Parent #{Process.pid} received SIGINT, forwarding to children..."
          interrupt!
        end
      end
    end

    def spawn(infrastructure = false, &blk)
      pid = fork(&blk)
      pids << pid
      infrastructure_pids << pid if infrastructure
    end

    def wait
      while active?
        if infrastructure_pid_missing?
          puts "We lost an infrastructure pid. Exiting..."
          interrupt!
          break
        elsif only_infrastructure_pids_remain?
          puts "Only infrastructure pids remain. Exiting..."
          interrupt!

          break
        end

        pids.each do |pid|
          pids.delete(pid) if Process.waitpid(pid, Process::WNOHANG)
        end

        puts "#{pids} remaining"
        sleep 0.1
      end
    end

    def interrupt!
      @interrupted = true

      pids.each do |pid|
        Process.kill("INT", pid)
      end

      pids.clear
    end

    def interrupted?
      @interrupted
    end

    def active?
      !interrupted? && pids.length.positive?
    end

    def only_infrastructure_pids_remain?
      infrastructure_pids.size.positive? && infrastructure_pids == pids
    end

    def infrastructure_pid_missing?
      (infrastructure_pids - pids).length.positive?
    end
  end
end
