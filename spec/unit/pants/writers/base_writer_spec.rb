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
        subject.starter.succeed
        subject.should be_running
      end
    end
  end
end
