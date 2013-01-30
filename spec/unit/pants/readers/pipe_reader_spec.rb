require 'spec_helper'
require 'pants/readers/pipe_reader'


describe Pants::Readers::PipeReader do
  describe '#start' do
    let(:cmd) { double "some command" }
    let(:starter) { double "EventMachine::Callback starter" }
    let(:stopper) { double "EventMachine::Callback stopper" }
    let(:core_stopper_callback) { double "EventMachine::Callback core stopper" }

    subject do
      Pants::Readers::PipeReader.new(cmd, core_stopper_callback)
    end

    before do
      subject.should_receive(:starter).twice.and_return(starter)
      subject.should_receive(:stopper).twice.and_return(stopper)
    end

    it "defines an EventMachine Callback" do
      EventMachine.should_receive(:Callback).any_number_of_times.and_yield.and_call_original

      EventMachine.should_receive(:popen).twice do |arg1, arg2, arg3, arg4, arg5|
        arg1.should == cmd
        arg2.should == Pants::Readers::PipeReaderConnection
        arg3.should be_a EventMachine::Channel
        arg4.should == starter
        arg5.should == stopper
      end

      subject.start
    end
  end
end
