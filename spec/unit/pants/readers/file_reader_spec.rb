require 'spec_helper'
require 'pants/readers/file_reader'


describe Pants::Readers::FileReader do
  let(:core_stopper_callback) do
    double "EventMachine.Callback"
  end

  subject do
    Pants::Readers::FileReader.new('some file', core_stopper_callback)
  end

  describe "#start" do
    let(:file) do
      double "File"
    end

    let(:starter) {  double "EventMachine::DefaultDeferrable" }
    let(:stopper) {  double "EventMachine::DefaultDeferrable" }

    let(:callback) do
      double "EventMachine.Callback", call: true
    end

    before do
      File.should_receive(:open).and_return(file)
      subject.should_receive(:starter).and_return(starter)
      subject.should_receive(:stopper).and_return(stopper)
    end

    it "defines an EventMachine Callback" do
      EventMachine.should_receive(:Callback).any_number_of_times.and_yield.and_return(callback)

      EventMachine.should_receive(:attach) do |arg1, arg2, arg3, arg4, arg5|
        arg1.should == file
        arg2.should == Pants::Readers::FileReaderConnection
        arg3.should be_a EventMachine::Channel
        arg4.should == starter
        arg5.should == stopper
      end

      subject.start
    end
  end
end

describe Pants::Readers::FileReaderConnection do
  let(:channel) { double "EventMachine::Channel" }
  let(:starter) { double "EventMachine::DefaultDeferrable starter" }
  let(:stopper) { double "EventMachine::DefaultDeferrable stopper" }

  subject do
    Pants::Readers::FileReaderConnection.new(1, channel, starter, stopper)
  end

  describe "#post_init" do
    let(:starter) do
      double "EventMachine::DefaultDeferrable"
    end

    it "tells the starter that it's started" do
      starter.should_receive(:succeed)
      subject
    end
  end

  describe "#receive_data" do
    let(:data) { "some data" }

    before do
      Pants::Readers::FileReaderConnection.any_instance.stub(:post_init)
    end

    it "directly writes it to the channel" do
      channel.should_receive(:<<).with(data)
      subject.receive_data(data)
    end
  end

  describe "#unbind" do
    before do
      Pants::Readers::FileReaderConnection.any_instance.stub(:post_init)
    end

    it "tells the stopper that it's stopped" do
      stopper.should_receive(:succeed)
      subject.unbind
    end
  end
end
