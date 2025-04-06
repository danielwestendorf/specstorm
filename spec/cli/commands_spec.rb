# frozen_string_literal: true

require "specstorm/cli/commands"

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
        .with(duration: 10)
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

      cli.call(arguments: ["serve"])
    end
  end

  describe "start" do
    it "runs the worker and server" do
      srv_dbl = instance_double(Specstorm::ForkedProcess)
      expect(srv_dbl).to receive(:stdout=)
        .with(instance_of(File))
      expect(srv_dbl).to receive(:stderr=)
        .with(instance_of(File))

      allow(supervisor_dbl).to receive(:spawn)
        .with(true)
        .and_yield
        .and_return(srv_dbl)

      allow(supervisor_dbl).to receive(:spawn)
        .with(no_args)
        .and_yield
        .and_return(instance_double(Specstorm::ForkedProcess))

      expect(Specstorm::Wrk).to receive(:run)
        .with(duration: 1)
        .and_return(true)
        .exactly(Etc.nprocessors)

      expect(Specstorm::Srv).to receive(:serve)
        .with(port: 5139)
        .and_return(true)
        .once

      cli.call(arguments: ["start", "--port=5139", "--duration=1"])
    end
  end
end
