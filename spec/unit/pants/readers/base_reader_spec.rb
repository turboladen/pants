require 'spec_helper'
require 'pants/readers/base_reader'


describe Pants::Readers::BaseReader do
  let(:test_writer) { double "Pants::Writers::TestWriter" }
  let(:core_stopper_callback) { double "EM.Callback" }
  subject { Pants::Readers::BaseReader.new(core_stopper_callback) }

  describe "#initialize" do
    it "creates a write_to_channel" do
      reader = Pants::Readers::BaseReader.new(core_stopper_callback)
      reader.write_to_channel.should be_a EM::Channel
    end
  end

  describe "#start" do
    around(:each) do |example|
      EM.run do
        example.run
        EM.stop
      end
    end

    let(:callback) { double "EventMachine.Callback" }

    let(:em_iterator) do
      EventMachine::Iterator.new([test_writer])
    end

    let(:tick_loop) do
      t = double "EventMachine::TickLoop"
      t.should_receive(:on_stop).and_yield

      t
    end

    before do
      subject.instance_variable_set(:@writers, [test_writer])
    end

    it "starts the writers first, then the readers" do
      EventMachine.stub(:tick_loop).and_yield.and_return(tick_loop)
      test_writer.stub(:running?).and_return(false, true)

      em_iterator.should_receive(:each).and_yield(test_writer, em_iterator)
      em_iterator.stub(:next)
      EventMachine::Iterator.should_receive(:new).and_return(em_iterator)
      test_writer.should_receive(:start)

      callback.should_receive(:call)

      subject.start(callback)
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

  describe "#remove_writer" do
    before do
      subject.instance_variable_set(:@writers, writers)
    end

    let(:writers) do
      [String.new, Hash.new, Array.new]
    end

    context "@writers doesn't contain a writer by the given class" do
      it "doesn't remove anything" do
        subject.remove_writer(URI, {})
        subject.writers.size.should be 3
      end
    end

    context "@writers contains a writer by the given class" do
      context "but doesn't match criteria given by key_value_pairs" do
        it "doesn't remove anything" do
          subject.remove_writer(String, size: 1)
          subject.writers.size.should be 3
        end
      end

      context "and criteria matches given key_value_pairs" do
        it "removes the matching object" do
          subject.remove_writer(String, size: 0)
          subject.writers.size.should be 2
        end
      end

      context "and criteria of more than 1 object matches given key_value_pairs" do
        let(:writers) do
          [String.new, String.new, String.new]
        end

        it "removes the matching object" do
          subject.remove_writer(String, size: 0)
          subject.writers.size.should be 0
        end
      end
    end
  end

  describe "#add_seam" do
    context "klass doesn't exist" do
      it "raises a NameError" do
        expect {
          subject.add_seam(BananaSplitPantsParty)
        }.to raise_error NameError
      end
    end

    context "klass exists" do
      let(:channel) do
        double "EventMachine::Channel"
      end

      let(:seam_class) do
        s = double "Pants::Seam"
        s.should_receive(:new).with(core_stopper_callback, channel).and_return(seam)

        s
      end

      let(:seam) do
        double "Pants::Seam"
      end

      before do
        subject.instance_variable_set(:@write_to_channel, channel)
      end

      it "creates the new object and adds it to the internal list of writers" do
        subject.add_seam(seam_class).should == seam
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
        core_stopper_callback.should_receive(:call)
        test_writer.should_receive(:running?)
        test_writer.should_receive(:stop)

        subject.send(:stopper).set_deferred_success
      end
    end
  end

  describe "#new_writer_from_uri" do
    let(:channel) do
      double "EventMachine::Channel"
    end

    context "uri_scheme exists in Pants.writers" do
      let(:test_writer) do
        double "Pants::Writers::TestWriter"
      end

      let(:writers) do
        [{ uri_scheme: 'test', klass: test_writer, args: [:host] }]
      end

      before do
        Pants.stub(:writers).and_return writers
      end

      it "creates a new Writer based on the scheme mapping" do
        uri = URI "test://testhost"
        test_writer.should_receive(:new).with("testhost", channel)

        subject.send(:new_writer_from_uri, uri, channel)
      end
    end

    context "uri_scheme does not exist in writers" do
      it "raises" do
        uri = URI "bobo://host:1234/path"

        expect {
          subject.send(:new_writer_from_uri, uri, channel)
        }.to raise_error(ArgumentError)
      end
    end
  end
end
