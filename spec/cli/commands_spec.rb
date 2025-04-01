# frozen_string_literal: true

require "specstorm/cli/commands"

RSpec.describe Specstorm::CLI::Commands do
  let(:cli) { Dry::CLI.new(Specstorm::CLI::Commands) }

  describe "version" do
    it "prints the version" do
      expect($stdout).to receive(:puts)
        .with(Specstorm::VERSION)

      cli.call(arguments: ["-v"])
    end
  end

  describe "work" do
    it "runs the worker" do
      expect(Specstorm::Wrk).to receive(:run)
        .with(duration: 10)
        .and_return(true)

      cli.call(arguments: ["work"])
    end
  end

  describe "serve" do
    it "runs the worker" do
      expect(Specstorm::Srv).to receive(:serve)
        .with(port: 5138)
        .and_return(true)

      cli.call(arguments: ["serve"])
    end
  end

  describe "start" do
    it "runs the worker and server" do
      expect(Specstorm::Wrk).to receive(:run)
        .with(duration: 1)
        .and_return(true)

      expect(Specstorm::Srv).to receive(:serve)
        .with(port: 5139)
        .and_return(true)

      cli.call(arguments: ["start", "--port=5139", "--duration=1"])
    end
  end
end
