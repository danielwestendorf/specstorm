# frozen_string_literal: true

require "specstorm/list_examples"

RSpec.describe Specstorm::ListExamples do
  describe "#examples" do 
    subject { instance.examples }

    let(:instance) { described_class.new("foo") }
    let(:runner_dbl) { instance_double(RSpec::Core::Runner) }
    let(:tmpfile_dbl) do 
      instance_double(Tempfile).tap do |dbl|
        allow(Tempfile).to receive(:new)
          .and_return(dbl)
      end
    end

    before do
      expect(RSpec.configuration).to receive(:files_or_directories_to_run=)
        .with("foo")

      expect(RSpec::Core::Formatters).to receive(:register)
        .with(described_class, :stop)

      expect(RSpec.configuration).to receive(:add_formatter)
        .with(instance)
      
      expect(RSpec.configuration).to receive(:files_to_run)
        .and_return(["1_spec.rb", "2_spec.rb"])

      configuration_options_dbl = instance_double(RSpec::Core::ConfigurationOptions).tap do |dbl|
        expect(RSpec::Core::ConfigurationOptions).to receive(:new)
          .with(["--dry-run", "1_spec.rb", "2_spec.rb"])
          .and_return(dbl)
      end

      expect(RSpec::Core::Runner).to receive(:new)
        .with(configuration_options_dbl)
        .and_return(runner_dbl)
    end

    context "successfully ran" do
      it "doesn't print the the out to stdout" do
        expect(runner_dbl).to receive(:run)
          .with($stderr, tmpfile_dbl)
          .and_return(0)

        expect(subject).to eq([])
      end
    end

    context "failed to run" do
      it "prints the out to stdout" do
        expect(runner_dbl).to receive(:run)
          .with($stderr, tmpfile_dbl)
          .and_return(1)

        expect(tmpfile_dbl).to receive(:rewind)
        expect(tmpfile_dbl).to receive(:each_line)
          .and_yield("1")

        expect($stdout).to receive(:print)
          .with("1")

        expect(subject).to eq([])
      end
    end
  end

  describe "#stop" do
    let(:instance) { described_class.new("spec") }

    let(:example_dbl) do
      instance_double(RSpec::Core::Example,
        id: "some-id",
        full_description: "does something cool",
        metadata: {
          file_path: "spec/models/foo_spec.rb",
          line_number: 42
        }
      )
    end

    let(:notification_dbl) { instance_double(RSpec::Core::Notifications::ExampleNotification, example: example_dbl) }
    let(:group_notification_dbl) { instance_double(RSpec::Core::Notifications::ExamplesNotification, notifications: [notification_dbl]) }

    it "populates @examples with example metadata" do
      instance.instance_variable_set(:@examples, [])

      instance.stop group_notification_dbl

      expect(instance.instance_variable_get(:@examples)).to eq([
        {
          id: "some-id",
          full_description: "does something cool",
          file_path: "spec/models/foo_spec.rb",
          line_number: 42
        }
      ])
    end
  end
end
