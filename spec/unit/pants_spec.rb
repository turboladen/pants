require 'spec_helper'
require "pants"


describe Pants do
  describe ".new_reader_from_uri" do
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
        test_reader.should_receive(:new).with("testhost", nil)

        Pants.new_reader_from_uri(uri)
      end
    end

    context "uri_scheme does not exist in readers" do
      it "raises" do
        uri = URI "bobo://host:1234/path"

        expect {
          Pants.new_reader_from_uri(uri)
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#add_reader" do
    context "unknown URI scheme" do
      it "raises an ArgumentError" do
        expect {
          subject.add_reader("test://stuff")
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
        Pants.should_receive(:new_reader_from_uri).with(uri, nil).
          and_return test_reader
        subject.add_reader('test://somehost')
      end
    end
  end

  describe "#run" do
    let(:reader) do
      r = double "Pants::TestReader"
      r.stub(:info)
      r.stub_chain(:writers, :size)

      r
    end

    before do
      EM.stub(:run).and_yield
    end

    it "starts all of the readers" do
      reader.should_receive(:start)
      subject.instance_variable_set(:@readers, [reader])
      subject.run
    end
  end
end
