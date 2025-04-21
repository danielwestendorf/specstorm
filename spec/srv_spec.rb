# frozen_string_literal: true

require "specstorm/srv"

RSpec.describe Specstorm::Srv do
  describe ".serve" do
    around do |ex|
      orginal_stdout = $stdout
      orginal_stderr = $stderr

      ex.run

      $stdout = orginal_stdout
      $stderr = orginal_stderr
    end

    it "starts serving the app" do
      expect(described_class::Web).to receive(:run!)
        .with(port: 1234)
        .and_return(true)

      described_class.serve(port: 1234)
    end
  end

  describe ".seed" do
    subject { described_class.seed(examples: [{id: 1}, {id: 2}]) }

    it { is_expected.to eq(2) }
  end
end
