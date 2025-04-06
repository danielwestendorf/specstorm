# frozen_string_literal: true

require "specstorm/supervisor"
require "specstorm/forked_process"

RSpec.describe Specstorm::Supervisor do
  let(:instance) { described_class.new }

  describe "#spawn" do
    subject { instance.spawn(infrastructure) { Kernel.sleep(1) } }

    let(:infrastructure) { false }
    let(:forked_process) { instance_double(Specstorm::ForkedProcess, pid: 123, infrastructure?: infrastructure, running?: true) }

    before do
      allow(Specstorm::ForkedProcess).to receive(:fork).and_yield.and_return(forked_process)
      allow(forked_process).to receive(:infrastructure=)
    end

    it "adds the forked process to processes" do
      expect(Kernel).to receive(:sleep).with(1)
      expect { subject }.to change { instance.processes.size }.from(0).to(1)
    end

    context "when infrastructure is true" do
      let(:infrastructure) { true }

      it "marks the process as infrastructure" do
        expect(Kernel).to receive(:sleep).with(1)
        expect(forked_process).to receive(:infrastructure=).with(true)
        subject
        expect(instance.infrastructure_processes).to include(forked_process)
      end
    end
  end

  describe "#interrupt!" do
    let(:process_1) { instance_double(Specstorm::ForkedProcess, pid: 1, flush_pipes: true) }
    let(:process_2) { instance_double(Specstorm::ForkedProcess, pid: 2, flush_pipes: true) }

    it "kills all running processes" do
      instance.processes.concat([process_1, process_2])

      [process_1, process_2].each do |object|
        expect(object).to receive(:kill)
        allow(object).to receive(:running?)
          .and_return(true, false)
      end

      instance.interrupt!

      expect(instance.interrupted?).to be true
    end
  end

  describe "#active?" do
    subject { instance.active? }

    context "when interrupted" do
      before { instance.interrupt! }
      it { is_expected.to be false }
    end

    context "when not interrupted and has running processes" do
      before do
        running = instance_double(Specstorm::ForkedProcess, running?: true)
        instance.processes << running
      end
      it { is_expected.to be true }
    end

    context "when not interrupted and no running processes" do
      it { is_expected.to be false }
    end
  end

  describe "#only_infrastructure_processes_remain?" do
    subject { instance.only_infrastructure_processes_remain? }

    let(:infrastructure_process) { instance_double(Specstorm::ForkedProcess, infrastructure?: true, running?: true) }

    context "when no infrastructure processes" do
      before do
        process = instance_double(Specstorm::ForkedProcess, infrastructure?: false, running?: true)
        instance.processes << process
      end

      it { is_expected.to be false }
    end

    context "when mixed processes" do
      let(:process) { instance_double(Specstorm::ForkedProcess, infrastructure?: false, running?: true) }

      before do
        instance.processes.concat([infrastructure_process, process])
      end

      it { is_expected.to be false }
    end

    context "when only infrastructure processes are running" do
      before { instance.processes << infrastructure_process }

      it { is_expected.to be true }
    end
  end

  describe "#infrastructure_process_missing?" do
    subject { instance.infrastructure_process_missing? }

    let(:terminated_process) { instance_double(Specstorm::ForkedProcess, infrastructure?: true, running?: false) }
    let(:running_process) { instance_double(Specstorm::ForkedProcess, infrastructure?: true, running?: true) }

    before { instance.processes.concat([terminated_process, running_process]) }

    it { is_expected.to be true }

    context "when all infra processes are running" do
      let(:terminated_process) { instance_double(Specstorm::ForkedProcess, infrastructure?: true, running?: true) }

      it { is_expected.to be false }
    end
  end

  describe "#wait" do
    let(:infrastructure_process) { instance_double(Specstorm::ForkedProcess, infrastructure?: true, running?: false, pid: 1) }
    let(:process) { instance_double(Specstorm::ForkedProcess, infrastructure?: false, running?: true, pid: 2) }

    before do
      instance.processes.concat([infrastructure_process, process])

      allow(Thread).to receive(:new)
        .and_return(instance_double(Thread, kill: true, join: true))
    end

    context "when an infrastructure process is missing" do
      it "prints a message and interrupts" do
        instance.processes.each do |object|
          expect(object).to receive(:stdout=)
          expect(object).to receive(:stderr=)
        end

        instance.running_processes.each { |object| expect(object).to receive(:kill) }

        expect(instance).to receive(:interrupt!)
        expect { instance.wait }.to output(/We lost an infrastructure process/).to_stdout
      end
    end

    context "when only infrastructure processes remain" do
      it "prints a message and interrupts" do
        allow(instance).to receive(:infrastructure_process_missing?).and_return(false)
        allow(instance).to receive(:only_infrastructure_processes_remain?).and_return(true)
        allow(instance).to receive(:running_processes).and_return([infrastructure_process])
        expect(instance).to receive(:interrupt!)
        expect { instance.wait }.to output(/Only infrastructure processes remain/).to_stdout
      end
    end

    context "when all processes exit processly" do
      before do
        allow(instance).to receive(:infrastructure_process_missing?).and_return(false)
        allow(instance).to receive(:only_infrastructure_processes_remain?).and_return(false)

        # Simulate processes exiting
        call_count = 0
        allow(instance).to receive(:running_processes) do
          call_count += 1
          (call_count < 3) ? [infrastructure_process, process] : []
        end
      end

      it "waits until no processes are running" do
        expect { instance.wait }.to output(/Bye/).to_stdout
        expect(instance.running_processes).to be_empty
      end
    end
  end
end
