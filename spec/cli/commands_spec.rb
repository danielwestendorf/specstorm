# frozen_string_literal: true

require "specstorm/cli/commands"
require "specstorm/list_examples"
require "specstorm/srv"
require "specstorm/wrk"

RSpec.describe Specstorm::CLI::Commands do
  let(:cli) { Dry::CLI.new(Specstorm::CLI::Commands) }

  let(:supervisor_dbl) do
    instance_double(Specstorm::Supervisor).tap do |dbl|
      allow(Specstorm::Supervisor).to receive(:new)
        .and_return(dbl)

      allow(dbl).to receive(:wait)
        .and_return(true)
    end
  end

  describe "version" do
    it "prints the version" do
      expect($stdout).to receive(:puts)
        .with(Specstorm::VERSION)

      cli.call(arguments: ["-v"])
    end
  end

  describe "work" do
    it "runs the worker" do
      allow(supervisor_dbl).to receive(:spawn)
        .and_yield
        .and_return(SecureRandom.rand(1..1000))

      expect(Specstorm::Wrk).to receive(:run)
        .and_return(true)
        .exactly(Etc.nprocessors)

      cli.call(arguments: ["work"])
    end
  end

  describe "serve" do
    it "runs the worker" do
      expect(Specstorm::Srv).to receive(:serve)
        .with(port: 5138)
        .and_return(true)

      cli.call(arguments: ["serve", "spec"])
    end
  end

  describe "start" do
    it "runs the worker and server" do
      allow(Specstorm::Wrk::Client).to receive(:connect?)
        .and_return(true)

      srv_dbl = instance_double(Specstorm::ForkedProcess)

      allow(supervisor_dbl).to receive(:spawn)
        .with(true)
        .and_yield
        .and_return(srv_dbl)

      allow(supervisor_dbl).to receive(:spawn)
        .with(no_args)
        .and_yield
        .and_return(instance_double(Specstorm::ForkedProcess))

      expect(Specstorm::Wrk).to receive(:run)
        .and_return(true)
        .exactly(Etc.nprocessors)

      list_examples_dbl = instance_double(Specstorm::ListExamples)
      expect(Specstorm::ListExamples).to receive(:new)
        .with(File.expand_path("spec", Dir.pwd))
        .and_return(list_examples_dbl)

      expect(list_examples_dbl).to receive(:examples)
        .and_return([])

      expect(Specstorm::Srv).to receive(:seed)
        .with(examples: [])

      expect(Specstorm::Srv).to receive(:serve)
        .with(port: 5139, verbose: true)
        .and_return(true)
        .once

      cli.call(arguments: ["start", "spec", "--port=5139", "--verbose"])
    end
  end
end
