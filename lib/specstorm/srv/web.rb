# frozen_string_literal: true

require "sinatra"
require "json"
require "etc"

module Specstorm
  module Srv
    class Web < Sinatra::Base
      set :default_content_type, :json
      set :server_settings, {
        Threads: ["0", ENV.fetch("PUMA_MAX_THREADS", Etc.nprocessors)].join(":"),
        PersistentTimeout: 300
      }

      get "/ping" do
        status 200
      end

      post "/poll" do
        example = PENDING_QUEUE.shift

        if example.nil?
          status 410 # nothing left to do
        else
          PROCESSING_QUEUE[example[:id]] = example
          [example].to_json
        end
      end

      patch "/complete/:id" do
        example = PROCESSING_QUEUE.delete params["id"]

        if example
          COMPLETED_QUEUE[example[:id]] = example
        end

        status 200
      end
    end
  end
end
