# frozen_string_literal: true

RSpec.describe Specstorm::Wrk::Client do
  let(:base_url) { "http://localhost:13345" }

  around { |ex|
    ENV["SPECSTORM_SRV_URI"] = base_url
    ex.run
    ENV["SPECSTORM_SRV_URI"] = nil
  }

  describe ".connect?" do
    subject { described_class.connect? }

    context "if the server is reachable" do
      it { is_expected.to eq(true) }
    end

    context "if the server is unreachable" do
      around { |ex|
        WebMock.disable!
        ex.run
        WebMock.enable!
      }

      it { is_expected.to eq(false) }
    end
  end

  describe "#close" do
    it "finishes the HTTP connection" do
      client = described_class.new
      expect { client.close }.not_to raise_error
    end
  end

  describe "#ping" do
    it "returns true when /poll returns 200" do
      stub_request(:post, "#{base_url}/poll").to_return(status: 200)

      client = described_class.new
      expect(client.ping).to eq(true)
    end
  end

  describe "#fetch_examples" do
    subject { client.fetch_examples }

    let(:client) { described_class.new }

    before do
      stub_request(:post, "#{base_url}/poll")
        .to_return(status: status, body: body)
    end

    context "200 response" do
      let(:status) { 200 }
      let(:body) { {id: "abc", description: "some test"}.to_json }

      it { is_expected.to eq(id: "abc", description: "some test") }
    end

    context "410 response" do
      let(:status) { 410 }
      let(:body) { "" }

      it { expect { subject }.to raise_error(Specstorm::Wrk::NoMoreExamplesError) }
    end

    context "unknown response" do
      let(:status) { 500 }
      let(:body) { "Error!" }

      it { expect { subject }.to raise_error(Specstorm::Wrk::UnhandledResponseError, "500: Error!") }
    end
  end
end
