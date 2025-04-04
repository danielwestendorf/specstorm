# frozen_string_literal: true

require "specstorm/supervisor"

RSpec.describe Specstorm::Supervisor do
  let(:instance) { described_class.new }

  describe "#spawn" do
    subject { instance.spawn(infrastructure) { Kernel.sleep(1) } }

    let(:infrastructure) { false }

    before do
      allow(instance).to receive(:fork)
        .and_yield
        .and_return(SecureRandom.rand(1..1000))
    end

    context "forks" do
      it "adds the pid to the pids" do
        expect(Kernel).to receive(:sleep)
          .with(1)

        expect { subject }.to change(instance.pids, :size).from(0).to(1)
        expect(instance.infrastructure_pids.size).to eq(0)
      end
    end

    context "infrastructure" do
      let(:infrastructure) { true }

      it "adds the pid to the pids an infrastructure_pids" do
        expect(Kernel).to receive(:sleep)
          .with(1)

        expect { subject }.to change(instance.infrastructure_pids, :size).from(0).to(1)
        expect(instance.pids.size).to eq(1)
      end
    end
  end

  describe "#interrupt!" do
    it "kills all child processes and clears the pid list" do
      pids = [123, 456]
      allow(instance).to receive(:pids).and_return(pids)
      expect(Process).to receive(:kill).with("INT", 123)
      expect(Process).to receive(:kill).with("INT", 456)

      instance.interrupt!
      expect(instance.pids).to be_empty
      expect(instance.interrupted?).to be true
    end
  end

  describe "#active?" do
    subject { instance.active? }

    context "has been interrupted" do
      before { instance.interrupt! }

      it { is_expected.to eq(false) }
    end

    context "hasn't been interrupted and pids exist" do
      before { instance.pids << 123 }

      it { is_expected.to eq(true) }
    end

    context "hasn't been interrupted but no pids" do
      it { is_expected.to eq(false) }
    end
  end

  describe "#only_infrastructure_pids_remain?" do
    subject { instance.only_infrastructure_pids_remain? }

    context "no infrastructure pids" do
      before { instance.pids << 123 }

      it { is_expected.to eq(false) }
    end

    context "infrastructure pids do not equal the pids" do
      before do
        instance.pids << 1
        instance.pids << 2
        instance.infrastructure_pids << 1
      end

      it { is_expected.to eq(false) }
    end

    context "infrastructure pids equals the pids" do
      before do
        instance.pids << 1
        instance.pids << 2
        instance.infrastructure_pids << 1
        instance.infrastructure_pids << 2
      end

      it { is_expected.to eq(true) }
    end
  end

  describe "#infrastructure_pid_missing?" do
    subject { instance.infrastructure_pid_missing? }

    context "pids includes all the infrastructure pids" do
      before do
        instance.pids << 1
        instance.infrastructure_pids << 1
      end

      it { is_expected.to eq(false) }
    end

    context "pids is missing an infrastructure pid" do
      before do
        instance.pids << 1
        instance.infrastructure_pids << 1
        instance.infrastructure_pids << 2
      end

      it { is_expected.to eq(true) }
    end
  end

  describe "#wait" do
    before do
      instance.pids.concat([1, 2])
      allow(Process).to receive(:waitpid).and_return(nil)
      allow(instance).to receive(:sleep)
    end

    context "when an infrastructure pid is missing" do
      before do
        instance.infrastructure_pids.concat([1])
        instance.pids.delete(1)
      end

      it "prints a message and interrupts" do
        expect(instance).to receive(:infrastructure_pid_missing?).and_return(true)
        expect(instance).to receive(:interrupt!)
        expect { instance.wait }.to output(/We lost an infrastructure pid/).to_stdout
      end
    end

    context "when only infrastructure pids remain" do
      before do
        instance.infrastructure_pids.concat([2])
        instance.pids.replace([2])
      end

      it "prints a message and interrupts" do
        allow(instance).to receive(:infrastructure_pid_missing?).and_return(false)
        expect(instance).to receive(:only_infrastructure_pids_remain?).and_return(true)
        expect(instance).to receive(:interrupt!)
        expect { instance.wait }.to output(/Only infrastructure pids remain/).to_stdout
      end
    end

    context "when children exit normally" do
      it "waits for all children to exit and clears pids" do
        allow(instance).to receive(:infrastructure_pid_missing?).and_return(false)
        allow(instance).to receive(:only_infrastructure_pids_remain?).and_return(false)

        # Simulate one child exiting each loop iteration
        expect(Process).to receive(:waitpid).with(1, Process::WNOHANG).and_return(1)
        expect(Process).to receive(:waitpid).with(2, Process::WNOHANG).and_return(2)

        instance.wait
        expect(instance.pids).to be_empty
      end
    end
  end
end
