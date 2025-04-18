# frozen_string_literal: true

require "specstorm/forked_process"

RSpec.describe Specstorm::ForkedProcess do
  describe ".fork" do
    subject(:forked_process) { described_class.fork(&blk) }

    let(:blk) {
      -> {
        $stdout.puts "mocked stdout"
      }
    }

    before do
      allow(Process).to receive(:fork).and_yield.and_return(1234)
      allow(IO).to receive(:pipe).and_return([double("reader", close: true, read: "mocked io"), double("writer", close: true)])
      allow($stdout).to receive(:reopen)
      allow($stderr).to receive(:reopen)
      allow($stdout).to receive(:sync=)
      allow($stderr).to receive(:sync=)
      allow($stdout).to receive(:puts)
    end

    it "calls the block and returns an instance with a pid" do
      expect(forked_process).to be_a(described_class)
      expect(forked_process.pid).to eq(1234)
    end

    it "redirects stdout and stderr to writer ends" do
      expect($stdout).to receive(:reopen).with(forked_process.stdout_writer)
      expect($stderr).to receive(:reopen).with(forked_process.stderr_writer)

      expect($stdout).to receive(:puts)
        .and_return(true)

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

  describe "#flush_pipes" do
    let(:instance) { described_class.new }

    it "calls #flush_reader_to_buffer for each reader" do
      expect(instance).to receive(:flush_reader_to_buffer)
        .with(reader: instance.stdout_reader, buffer: instance.instance_variable_get(:@stdout_output_buffer), to: instance.stdout)
      expect(instance).to receive(:flush_reader_to_buffer)
        .with(reader: instance.stderr_reader, buffer: instance.instance_variable_get(:@stderr_output_buffer), to: instance.stderr)

      instance.flush_pipes
    end
  end

  describe "#echo" do
    let(:instance) { described_class.new }
    let(:chunks) { ["foo", "bar"] }
    let(:to) { IO.pipe.last }

    it "prints each chunk except the deliminator" do
      expect(to).to receive(:print)
        .with("foo")

      expect(to).to receive(:print)
        .with("bar")

      instance.echo(chunks: chunks, to: to)
    end
  end

  describe "#flush_reader_to_buffer" do
    subject { instance.flush_reader_to_buffer(reader: reader, buffer: buffer, to: to_dbl) }

    let(:instance) { described_class.new }
    let(:pipes) { IO.pipe }
    let(:reader) { pipes.first }
    let(:writer) { pipes.last }
    let(:buffer) { String.new } # standard:disable Performance/UnfreezeString
    let(:to_dbl) { instance_double(IO) }

    context "nothing flushed to the buffer" do
      it "doesn't echo, doesn't block" do
        expect(instance).not_to receive(:echo)

        subject
      end
    end

    context "non-blank buffer" do
      let(:instance) { described_class.new }
      let(:content_to_buffer) { "foo#{described_class::FLUSH_DELIMINATOR}bar" }

      before do
        writer.print content_to_buffer
      end

      context "infrastructure" do
        before do
          allow(instance).to receive(:running?)
            .and_return(true)

          allow(instance).to receive(:infrastructure?)
            .and_return(true)
        end

        it "echos foo and bar" do
          expect(instance).to receive(:echo)
            .with(chunks: ["foo", "bar"], to: to_dbl)

          subject
        end
      end

      context "no longer running?" do
        before do
          allow(instance).to receive(:running?)
            .and_return(false)

          allow(instance).to receive(:infrastructure?)
            .and_return(true)
        end

        it "echos foo and bar" do
          expect(instance).to receive(:echo)
            .with(chunks: ["foo", "bar"], to: to_dbl)

          subject
        end
      end

      context "running non-infrastructure" do
        before do
          allow(instance).to receive(:running?)
            .and_return(true)

          allow(instance).to receive(:infrastructure?)
            .and_return(false)
        end

        context "no deliminator" do
          let(:content_to_buffer) { "foobar" }

          it "doesn't echo any chunks, pushes back to buffer" do
            expect(instance).to receive(:echo)
              .with(chunks: [], to: to_dbl)

            subject

            expect(buffer).to eq("foobar")
          end
        end

        context "has deliminator, but does not end with deliminator" do
          let(:content_to_buffer) { "foo#{described_class::FLUSH_DELIMINATOR}bar" }

          it "echos first chunk, pushes remainder back to buffer" do
            expect(instance).to receive(:echo)
              .with(chunks: ["foo"], to: to_dbl)

            subject

            expect(buffer).to eq("bar")
          end
        end

        context "ends with deliminator" do
          let(:content_to_buffer) { "foo#{described_class::FLUSH_DELIMINATOR}bar#{described_class::FLUSH_DELIMINATOR}" }

          it "echos all chunks, buffer is now clear" do
            expect(instance).to receive(:echo)
              .with(chunks: ["foo", "bar"], to: to_dbl)

            subject

            expect(buffer).to eq("")
          end
        end
      end
    end
  end
end
