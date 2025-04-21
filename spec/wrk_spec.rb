# frozen_string_literal: true

require "specstorm/wrk"

RSpec.describe Specstorm::Wrk do
  describe ".run" do
    let(:client_dbl) { instance_double(Specstorm::Wrk::Client, close: true) }

    around do |ex|
      ENV["SPECSTORM_FLUSH_DELIMINATOR"] = "FOOBAR"

      ex.run

      ENV["SPECSTORM_FLUSH_DELIMINATOR"] = nil
    end

    it "executes examples until client raises" do
      expect(Specstorm::Wrk::Client).to receive(:new)
        .and_return(client_dbl)

      expect(client_dbl).to receive(:fetch_examples)
        .and_return(0)

      expect(client_dbl).to receive(:fetch_examples)
        .and_return(1)

      expect(client_dbl).to receive(:fetch_examples)
        .and_raise(Specstorm::Wrk::NoMoreExamplesError)

      expect(described_class).to receive(:reset_rspec!).twice
      expect(described_class).to receive(:flush).twice

      expect(described_class).to receive(:execute)
        .with(0)

      expect(described_class).to receive(:execute)
        .with(1)

      expect(described_class.run).to eq(true)
    end
  end

  describe ".execute" do
    subject { described_class.execute(examples) }

    let(:examples) { [{id: "foo_spec.rb:1"}, {id: "bar_spec.rb:32"}] }

    before do
      expect(RSpec.configuration).to receive(:add_formatter)
        .with(Specstorm::Wrk::ProgressFormatter)

      expect(RSpec.configuration).to receive(:silence_filter_announcements=)
        .with(true)

      configuration_options_dbl = instance_double(RSpec::Core::ConfigurationOptions).tap do |dbl|
        expect(RSpec::Core::ConfigurationOptions).to receive(:new)
          .with(["--format", "Specstorm::Wrk::ProgressFormatter", *examples.map { |ex| ex[:id] }])
          .and_return(dbl)
      end

      instance_double(RSpec::Core::Runner).tap do |dbl|
        expect(RSpec::Core::Runner).to receive(:new)
          .with(configuration_options_dbl)
          .and_return(dbl)

        expect(dbl).to receive(:run)
          .with(instance_of(IO), instance_of(IO))
          .and_return(0)
      end
    end

    it { is_expected.to eq(0) }
  end

  describe ".reset_rspec!" do
    it do
      expect(RSpec).to receive(:clear_examples)

      expect(RSpec.world).to receive(:non_example_failure=)
        .with(false)
      expect(RSpec.world).to receive(:wants_to_quit=)
        .with(false)

      described_class.reset_rspec!
    end
  end
end
