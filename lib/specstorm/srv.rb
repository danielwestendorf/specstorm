# frozen_string_literal: true

require_relative "srv/web"
require_relative "srv/queue"

module Specstorm
  module Srv
    class Error < StandardError; end

    PENDING_QUEUE = Queue.new
    PROCESSING_QUEUE = Queue.new
    COMPLETED_QUEUE = Queue.new

    def self.seed(examples:)
      examples.each do |example|
        PENDING_QUEUE[example[:id]] = example
      end

      PENDING_QUEUE.length
    end

    def self.serve(port: 5138, verbose: false)
      $stdout = $stderr = File.open(File::NULL, "w") unless verbose

      Web.run!(port: port)
    end
  end
end
