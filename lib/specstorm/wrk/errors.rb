module Specstorm
  module Wrk
    Error = Class.new(StandardError)
    ClientError = Class.new(Error)
    UnhandledResponseError = Class.new(ClientError)
    NoMoreExamplesError = Class.new(ClientError)
  end
end
