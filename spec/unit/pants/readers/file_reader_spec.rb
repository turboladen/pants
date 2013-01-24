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

    let(:starter) do
      double "EventMachine::DefaultDeferrable"
    end

    let(:stopper) do
      double "EventMachine::DefaultDeferrable"
    end

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
