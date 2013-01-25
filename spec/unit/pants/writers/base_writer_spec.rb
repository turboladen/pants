require 'spec_helper'
require 'pants/writers/base_writer'


describe Pants::Writers::BaseWriter do
  let(:channel) { double "EventMachine::Channel" }

  subject do
    Pants::Writers::BaseWriter.new(channel)
  end

  describe "#starter" do
    context "@starter not yet defined" do
      it "creates a new deferrable that sets @running to true" do
        subject.should_not be_running
        subject.starter.call
        subject.should be_running
      end
    end
  end

  describe "#stopper" do
    context "@stopper not yet defined and @running is true" do
      before do
        subject.instance_variable_set(:@running, true)
      end

      it "creates a new deferrable that sets @running to false" do
        subject.should be_running
        subject.stopper.call
        subject.should_not be_running
      end
    end
  end
end
