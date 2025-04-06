# frozen_string_literal: true

module Specstorm
  class ForkedProcess
    FLUSH_DELIMINATOR = "SPECSTORM--FLUSH--DELIMINATOR"

    attr_accessor :pid, :infrastructure, :stdout, :stderr
    attr_reader :stdout_reader, :stdout_writer, :stderr_reader, :stderr_writer

    def self.fork(&blk)
      instance = new

      instance.pid = Process.fork do
        ENV["SPECSTORM_FLUSH_DELIMINATOR"] = FLUSH_DELIMINATOR

        instance.stdout_reader.close
        instance.stderr_reader.close

        $stdout.reopen(instance.stdout_writer)
        $stderr.reopen(instance.stderr_writer)

        $stdout.sync = true
        $stderr.sync = true

        blk.call
      end

      instance.stdout_writer.close
      instance.stderr_writer.close

      instance
    end

    def initialize
      @infrastructure = false
      @stdout_reader, @stdout_writer = IO.pipe
      @stderr_reader, @stderr_writer = IO.pipe

      @stdout_output_buffer = String.new # standard:disable Performance/UnfreezeString
      @stderr_output_buffer = String.new # standard:disable Performance/UnfreezeString

      @stdout = $stdout
      @stderr = $stderr
    end

    def flush_pipes
      flush_reader_to_buffer(reader: stdout_reader, buffer: @stdout_output_buffer, to: stdout)
      flush_reader_to_buffer(reader: stderr_reader, buffer: @stderr_output_buffer, to: stderr)
    end

    def kill
      if @killed
        Process.kill("TERM", pid)
      else
        Process.kill("INT", pid)
        @killed = true
      end
    end

    def running?
      exited_pid.nil?
    end

    def exited_pid
      @exited_pid ||= Process.wait(pid, Process::WNOHANG) # returns nil if running
    end

    def infrastructure?
      @infrastructure
    end

    private

    def flush_reader_to_buffer(reader:, buffer:, to:)
      loop do
        buffer << reader.read_nonblock(1024)
      rescue EOFError, IO::WaitReadable
        break
      end

      return if buffer.length.zero?

      chunks = buffer.split(FLUSH_DELIMINATOR)
      buffer.clear
      buffer << chunks.pop if !infrastructure? && running? && chunks.last != FLUSH_DELIMINATOR

      echo(chunks: chunks, to: to)
    end

    def echo(chunks:, to:)
      chunks.each do |chunk|
        to.print chunk unless chunk == FLUSH_DELIMINATOR
      end
    end
  end
end
