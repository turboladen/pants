require 'spec_helper'
require 'pants/writers/file_writer'


describe Pants::Writers::FileWriter do
  let(:channel) { EventMachine::Channel.new }

  subject do
    Pants::Writers::FileWriter.new(file, channel)
  end

  describe "#stop" do
    let(:file) do
      c = double "File"
      c.should_receive(:closed?).and_return(false)
      c.should_receive(:close)

      c
    end

    let(:stopper) do
      s = double "EventMachine::Callback"
      s.should_receive(:call)

      s
    end

    before do
      File.stub(:open)
      subject.instance_variable_set(:@file, file)
    end

    it "closes the file and calls succeed on the stopper" do
      subject.should_receive(:stopper).and_return(stopper)
      subject.stop
    end
  end

  describe "#start" do
    let(:data) do
      '0' * 100
    end

    let(:file) do
      f = double "File"
      f.should_receive(:write_nonblock).once.with(data).and_return(data.size)
      f.should_receive(:closed?).and_return(true)

      f
    end

    let(:tick_loop) do
      t = double "EventMachine::TickLoop"
      t.should_receive(:on_stop).and_yield

      t
    end

    before do
      File.should_receive(:open).and_return(file)
    end

    it "subscribes to the channel and writes data as it comes in" do
      EM.should_receive(:defer).and_yield
      channel.should_receive(:subscribe).and_yield(data).and_call_original
      EventMachine.should_receive(:tick_loop).and_yield.and_return(tick_loop)

      subject.start
    end
  end
end
