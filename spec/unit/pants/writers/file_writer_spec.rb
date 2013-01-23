require 'spec_helper'
require 'pants/writers/file_writer'


describe Pants::Writers::FileWriter do
  let(:channel) { EventMachine::Channel.new }

  subject do
    Pants::Writers::FileWriter.new(file, channel)
  end

  around do |example|
    EM.run do
      example.run
      EM.stop
    end
  end

  describe "#stop" do
    before do
      Pants::Writers::FileWriter.any_instance.stub(:start)
    end

    let(:file) do
      c = double "File"
      c.should_receive(:closed?).and_return(false)
      c.should_receive(:close)

      c
    end

    let(:stopper) do
      s = double "EventMachine::DefaultDeferrable"
      s.should_receive(:succeed)

      s
    end

    before do
      subject.instance_variable_set(:@file, file)
      subject.stub(:stopper).and_return(stopper)
    end

    it "closes the file and calls succeed on the stopper" do
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
      Pants::Writers::FileWriter.any_instance.should_receive(:start).and_call_original
      File.should_receive(:open).and_return(file)
    end

    it "subscribes to the channel and writes data as it comes in" do
      EM.should_receive(:defer).and_yield
      channel.should_receive(:subscribe).and_yield(data).and_call_original
      EventMachine.should_receive(:tick_loop).and_yield.and_return(tick_loop)

      subject
    end
  end
end
