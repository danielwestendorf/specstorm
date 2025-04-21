# frozen_string_literal: true

RSpec.describe Specstorm::Srv::Queue do
  describe "#[]=" do
    subject { instance[:foo] }

    let(:instance) { described_class.new }

    before { instance[:foo] = "bar" }

    context do
      it { is_expected.to eq("bar") }
    end
  end

  describe "#[]" do
    subject { instance[:foo] }

    let(:instance) { described_class.new(foo: "bar") }

    context do
      it { is_expected.to eq("bar") }
    end
  end

  describe "#length" do
    subject { instance.length }

    let(:instance) { described_class.new(foo: "bar", baz: "buzz") }

    context do
      it { is_expected.to eq(2) }
    end
  end

  describe "#shift" do
    let(:instance) { described_class.new(foo: "bar", baz: "buzz") }

    it "removes and returns the first inserted value" do
      expect(instance.shift).to eq("bar")
      expect(instance.length).to eq(1)

      expect(instance.shift).to eq("buzz")
      expect(instance.length).to eq(0)

      expect(instance.shift).to eq(nil)
      expect(instance.length).to eq(0)
    end
  end

  describe "#delete" do
    let(:instance) { described_class.new(foo: "bar") }

    it { expect(instance.delete(:foo)).to eq("bar") }
    it { expect { instance.delete(:foo) }.to change(instance, :length).to(0) }

    it { expect(instance.delete(:baz)).to eq(nil) }
    it { expect { instance.delete(:baz) }.not_to change(instance, :length) }
  end
end
