require 'spec_helper'
require 'pants/readers/base_reader'


describe Pants::Readers::BaseReader do
  let(:test_writer) do
    double "Pants::Writers::TestWriter"
  end

  before do
    Pants::Readers::BaseReader.any_instance.stub(:init_starter)
  end

  let(:callback) { double "EM.Callback" }

  subject { Pants::Readers::BaseReader.new(callback) }

  describe "#initialize" do
    it "creates a write_to_channel" do
      reader = Pants::Readers::BaseReader.new(callback)
      reader.write_to_channel.should be_a EM::Channel
    end
  end

  describe "#start" do
    around(:each) do |example|
      EM.run do
        example.run
        #EM.stop
        EM.add_timer(1) { EM.stop }
      end
    end

    let(:starter) do
      s = double "@starter"
      #s.should_receive(:call)

      s
    end

    it "starts the writers first, then the readers" do
      # It seems that any methods I expect to get called inside EM.next_tick
      # don't get registered as being called.  If I log inside there, I see that
      # things are as expected, but RSpec still fails the tests.
      pending "Figuring out how to set expectations inside EM.next_tick"
      subject.start
    end
  end

  describe "#stop!" do
    let(:stopper) do
      s = double "EventMachine::DefaultDeferrable"
      s.should_receive(:succeed)

      s
    end

    it "calls succeed on the stopper" do
      subject.should_receive(:stopper).and_return(stopper)

      subject.stop!
    end
  end

  describe "#write_to" do
    context "unknown URI scheme" do
      it "raises an ArgumentError" do
        expect {
          subject.write_to("test://stuff")
        }.to raise_error ArgumentError
      end
    end

    context "known URI scheme" do
      it "creates the new writer, adds it to @writers, and returns it" do
        uri = URI "test://somehost"
        subject.should_receive(:new_writer_from_uri) do |arg1, arg2|
          arg1.should == uri
          arg2.should be_a EventMachine::Channel
        end.and_return(test_writer)

        subject.write_to('test://somehost').should == test_writer
      end
    end
  end

  describe "#add_writer" do
    let(:obj_object) { double "TestWriter" }

    context "obj is a Class" do
      let(:obj) do
        class TestWriter; self; end
      end

      it "creates a new object of that class with all args and the write channel" do
        first_arg = double "first arg"
        second_arg = double "second arg"

        obj.should_receive(:new) do |arg1, arg2, arg3|
          arg1.should == first_arg
          arg2.should == second_arg
          arg3.should be_a EventMachine::Channel
        end.and_return(obj_object)

        subject.add_writer(obj, first_arg, second_arg).should == obj_object
      end
    end

    context "obj is a instantiated Writer object" do
      it "adds that object to the list of writers and returns it" do
        obj_object.should_receive(:kind_of?).with(Pants::Writers::BaseWriter).
          and_return(true)

        subject.add_writer(obj_object).should == obj_object
      end
    end

    context "obj isn't a Class and isn't a Writer" do
      it "raises a Pants::Error" do
        expect {
          subject.add_writer("meow")
        }.to raise_error Pants::Error
      end
    end
  end

  describe "#stopper" do
    context "when called back with success" do
      before do
        subject.instance_variable_set(:@writers, [test_writer])
        EM.stub(:next_tick).and_yield
        EM.stub(:tick_loop).and_yield.and_return(tick_loop)
        EM::Iterator.stub(:new).and_return(iterator)
      end

      let(:tick_loop) do
        t = double "EventMachine::TickLoop"
        t.should_receive(:on_stop).and_yield

        t
      end

      let(:iterator) do
        i = double "EventMachine::Iterator"
        i.should_receive(:each).and_yield(test_writer, i)
        i.stub(:next)

        i
      end

      it "calls each writer's stopper and the main callback" do
        callback.should_receive(:call)
        test_writer.should_receive(:running?)
        test_writer.should_receive(:stop)

        subject.send(:stopper).set_deferred_success
      end
    end
  end
end
