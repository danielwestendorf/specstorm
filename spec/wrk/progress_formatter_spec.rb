# frozen_string_literal: true

RSpec.describe Specstorm::Wrk::ProgressFormatter do
  before do
    # Stub the registration call before the formatter is loaded
    allow(RSpec::Core::Formatters).to receive(:register)
    load File.expand_path("../../lib/specstorm/wrk/progress_formatter.rb", __dir__)
  end

  let(:instance) { described_class.new(output) }
  let(:output) { StringIO.new }

  let(:notification) { instance_double(RSpec::Core::Notifications::ExampleNotification) }

  describe "#example_passed" do
    subject { instance.example_passed(notification) }

    it { expect { subject }.to change(output, :string).to(RSpec::Core::Formatters::ConsoleCodes.wrap(".", :success)) }
  end

  describe "#example_pending" do
    subject { instance.example_pending(notification) }

    it { expect { subject }.to change(output, :string).to(RSpec::Core::Formatters::ConsoleCodes.wrap("*", :pending)) }
  end

  describe "#example_failed" do
    subject { instance.example_failed(notification) }

    it { expect { subject }.to change(output, :string).to(RSpec::Core::Formatters::ConsoleCodes.wrap("F", :failure)) }
  end
end
