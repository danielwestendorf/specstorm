# frozen_string_literal: true

require "specstorm/forked_process"

RSpec.describe Specstorm::ForkedProcess do
  describe ".fork" do
    subject(:forked_process) { described_class.fork(&blk) }

    let(:blk) {
      -> {
        puts "mocked stdout"
        warn "mocked stderr"
      }
    }

    before do
      allow(Process).to receive(:fork).and_yield.and_return(1234)
      allow(IO).to receive(:pipe).and_return([double("reader", close: true, read: "mocked io"), double("writer", close: true)])
      allow($stdout).to receive(:reopen)
      allow($stderr).to receive(:reopen)
      allow($stdout).to receive(:sync=)
      allow($stderr).to receive(:sync=)
    end

    it "calls the block and returns an instance with a pid" do
      expect(forked_process).to be_a(described_class)
      expect(forked_process.pid).to eq(1234)
    end

    it "redirects stdout and stderr to writer ends" do
      expect($stdout).to receive(:reopen).with(forked_process.stdout_writer)
      expect($stderr).to receive(:reopen).with(forked_process.stderr_writer)
      described_class.fork(&blk)
    end
  end

  describe "#kill" do
    let(:instance) { described_class.new.tap { |i| i.pid = 42 } }

    it "sends an INT signal to the process on the first INT, TERM after that" do
      expect(Process).to receive(:kill)
        .with("INT", instance.pid)
        .once

      expect(Process).to receive(:kill)
        .with("TERM", instance.pid)
        .twice

      instance.kill
      instance.kill
      instance.kill
    end
  end

  describe "#running?" do
    subject { instance.running? }

    let(:instance) { described_class.new.tap { |i| i.pid = 42 } }

    before do
      allow(instance).to receive(:exited_pid)
        .and_return(exited_pid)
    end

    context "returns true when exited_pid returns nil" do
      let(:exited_pid) { nil }

      it { is_expected.to eq(true) }
    end

    context "returns true when exited_pid returns the pid" do
      let(:exited_pid) { instance.pid }

      it { is_expected.to eq(false) }
    end
  end

  describe "#exited_pid" do
    subject { instance.exited_pid }

    let(:instance) { described_class.new.tap { |i| i.pid = 42 } }

    context "response" do
      before do
        allow(Process).to receive(:wait)
          .with(instance.pid, Process::WNOHANG)
          .and_return(wait_response)
      end

      context "returns nil if the process is still running" do
        let(:wait_response) { nil }

        it { is_expected.to eq(nil) }
      end

      context "returns pid if the process is no longer running" do
        let(:wait_response) { instance.pid }

        it { is_expected.to eq(instance.pid) }
      end
    end

    context "memoizes correctly" do
      it "caches the exited pid after first check" do
        allow(Process).to receive(:wait)
          .with(instance.pid, Process::WNOHANG)
          .and_return(nil)
          .once

        expect(instance.exited_pid).to eq(nil)

        allow(Process).to receive(:wait)
          .with(instance.pid, Process::WNOHANG)
          .and_return(instance.pid)
          .once

        expect(instance.exited_pid).to eq(instance.pid)
        expect(instance.exited_pid).to eq(instance.pid)
      end
    end
  end

  describe "#infrastructure?" do
    it "returns false by default" do
      process = described_class.new
      expect(process.infrastructure?).to be false
    end

    it "returns true if infrastructure is set" do
      process = described_class.new
      process.infrastructure = true
      expect(process.infrastructure?).to be true
    end
  end
end
