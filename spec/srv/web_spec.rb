# frozen_string_literal: true

require "specstorm/srv"
require "specstorm/srv/queue"

RSpec.describe Specstorm::Srv::Web do
  def app
    Specstorm::Srv::Web
  end

  let(:example) { {id: "123", name: "Sample Test"} }

  before do
    stub_const("Specstorm::Srv::PENDING_QUEUE", Specstorm::Srv::Queue.new)
    stub_const("Specstorm::Srv::PROCESSING_QUEUE", Specstorm::Srv::Queue.new)
    stub_const("Specstorm::Srv::COMPLETED_QUEUE", Specstorm::Srv::Queue.new)
  end

  describe "POST /poll" do
    context "when there is an example in the pending queue" do
      before { Specstorm::Srv::PENDING_QUEUE["123"] = example }

      it "returns the example and stores it in processing queue" do
        post "/poll"

        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq(["id" => "123", "name" => "Sample Test"])
        expect(Specstorm::Srv::PROCESSING_QUEUE["123"]).to eq(example)
      end
    end

    context "when the queue is empty" do
      it "returns status 410" do
        post "/poll"
        expect(last_response.status).to eq(410)
      end
    end
  end

  describe "PATCH /complete/:id" do
    before do
      Specstorm::Srv::PROCESSING_QUEUE["123"] = example
    end

    it "moves the example to the completed queue" do
      patch "/complete/123"

      expect(last_response.status).to eq(200)
      expect(Specstorm::Srv::PROCESSING_QUEUE.length).to eq(0)
      expect(Specstorm::Srv::COMPLETED_QUEUE["123"]).to eq(example)
    end

    it "still returns 200 even if the ID isn't found" do
      patch "/complete/999"
      expect(last_response.status).to eq(200)
    end
  end
end
