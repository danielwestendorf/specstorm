# frozen_string_literal: true

module Specstorm
  module Srv
    # Thread-safe Hash access
    class Queue
      def initialize(hash = {})
        @hash = hash
        @mutex = Mutex.new
      end

      def length
        @mutex.synchronize { @hash.keys.length }
      end

      def []=(key, value)
        @mutex.synchronize { @hash[key] = value }
      end

      def [](key)
        @mutex.synchronize { @hash[key] }
      end

      # Take the first element from the hash
      def shift
        value = nil

        @mutex.synchronize do
          key = @hash.keys.first
          break if key.nil?

          value = @hash[key]
          @hash.delete key
        end

        value
      end

      def delete(key)
        @mutex.synchronize { @hash.delete(key) }
      end
    end
  end
end
