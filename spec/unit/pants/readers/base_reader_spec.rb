require 'spec_helper'
require 'pants/readers/base_reader'


describe Pants::Readers::BaseReader do
  let(:test_writer) do
    double "Pants::TestWriter"
  end

  before do
    Pants::Readers::BaseReader.any_instance.stub(:init_starter)
  end

  let(:callback) { double "EM.Callback" }

  subject { Pants::Readers::BaseReader.new(callback) }

  describe "#initialize" do
    it "creates a write_to_channel if one isn't passed in" do
      reader = Pants::Readers::BaseReader.new(callback)
      reader.write_to_channel.should be_a EM::Channel
    end
  end

  describe "#finisher" do
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

      it "calls each writer's finisher and the main callback" do
        callback.should_receive(:call)
        test_writer.should_receive(:running?)
        test_writer.should_receive(:stop)

        subject.send(:finisher).set_deferred_success
      end
    end
  end

  describe "#add_writer" do
    context "unknown URI scheme" do
      it "raises an ArgumentError" do
        expect {
          subject.add_writer("test://stuff")
        }.to raise_error ArgumentError
      end
    end

    context "known URI scheme" do
      let(:writers) do
        [{ uri_scheme: 'test', klass: test_writer }]
      end

      before do
        Pants.stub(:writers).and_return writers
      end

      it "creates the new writer and adds it to @writers" do
        uri = URI "test://somehost"
        subject.should_receive(:new_writer_from_uri) do |arg1, arg2|
          arg1.should == uri
          arg2.should be_a EventMachine::Channel
        end

        subject.add_writer('test://somehost')
      end
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
end