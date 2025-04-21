# frozen_string_literal: true

require "uri"
require "net/http"
require "json"

require_relative "errors"

module Specstorm
  module Wrk
    class Client
      def self.connect?(srv: nil)
        http = build_http(srv || ENV.fetch("SPECSTORM_SRV_URI", "http://localhost:5138"))
        http.start
        http.finish

        true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        false
      end

      def self.build_http(uri)
        uri = URI(uri)
        Net::HTTP.new(uri.host, uri.port)
      end

      def initialize(srv: nil)
        @http = self.class.build_http(srv || ENV.fetch("SPECSTORM_SRV_URI", "http://localhost:5138"))
        @http.keep_alive_timeout = 300
        @http.start
      end

      def close
        @http.finish
      end

      def ping
        request = Net::HTTP::Post.new("/poll")
        response = @http.request(request)

        response.code == "200"
      end

      def fetch_examples
        request = Net::HTTP::Post.new("/poll")
        response = @http.request(request)

        case response.code
        when "200"
          JSON.parse(response.body, symbolize_names: true)
        when "410"
          raise NoMoreExamplesError
        else
          raise UnhandledResponseError.new("#{response.code}: #{response.body}")
        end
      end
    end
  end
end
