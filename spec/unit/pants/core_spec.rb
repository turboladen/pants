require 'spec_helper'
require "pants/core"


describe Pants::Core do
  let(:callback) { double "EM.Callback" }

  describe "#read" do
    context "unknown URI scheme" do
      it "raises an ArgumentError" do
        expect {
          subject.read("test://stuff")
        }.to raise_error ArgumentError
      end
    end

    context "known URI scheme" do
      let(:test_reader) do
        double "Pants::TestReader"
      end

      let(:readers) do
        [{ uri_scheme: 'test', klass: test_reader }]
      end

      before do
        Pants.stub(:readers).and_return readers
      end

      it "creates the new reader and adds it to @readers" do
        uri = URI "test://somehost"

        subject.should_receive(:new_reader_from_uri) do |arg1, arg2|
          arg1.should == uri
          arg2.should be_a EM.Callback
        end.and_return(test_reader)

        subject.read('test://somehost')
      end
    end
  end

  describe "#run" do
    let(:reader) do
      r = double "Pants::TestReader"
      r.stub(:read_object)
      r.stub_chain(:writers, :size)
      r.stub_chain(:writers, :each_with_index)

      r
    end

    let(:iterator) do
      i = double "EventMachine::Iterator"
      i.should_receive(:each).and_yield(reader, i)
      i.stub(:next)

      i
    end

    before do
      EM.stub(:run).and_yield
      EM::Iterator.stub(:new).and_return(iterator)
    end

    it "starts all of the readers" do
      reader.should_receive(:start)
      subject.instance_variable_set(:@readers, [reader])
      subject.run
    end
  end

  describe "#new_reader_from_uri" do
    context "uri_scheme exists in readers" do
      let(:test_reader) do
        double "Pants::TestReader"
      end

      let(:readers) do
        [{ uri_scheme: 'test', klass: test_reader, args: [:host] }]
      end

      before do
        Pants.stub(:readers).and_return readers
      end

      it "creates a new Reader based on the scheme mapping" do
        uri = URI "test://testhost"
        test_reader.should_receive(:new).with("testhost", callback)

        subject.send(:new_reader_from_uri, uri, callback)
      end
    end

    context "uri_scheme does not exist in readers" do
      it "raises" do
        uri = URI "bobo://host:1234/path"

        expect {
          subject.send(:new_reader_from_uri, uri, callback)
        }.to raise_error(ArgumentError)
      end
    end
  end
end
