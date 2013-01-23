require 'spec_helper'
require 'pants/writers/udp_writer'


describe Pants::Writers::UDPWriter do
  let(:channel) do
    double "EventMachine::Channel"
  end

  let(:ip) { '127.0.0.1' }
  let(:port) { 1234 }

  subject do
    Pants::Writers::UDPWriter.new(ip, port, channel)
  end

  before do
    subject.stub(:log)
  end

  describe "#start" do
    let(:starter) do
      s = double "EventMachine::DefaultDeferrable"
      s.should_receive(:succeed)

      s
    end

    let(:tick_loop) do
      t = double "EventMachine::TickLoop"
      t.should_receive(:on_stop).and_yield

      t
    end

    before do
      subject.stub(:starter).and_return(starter)
    end

    it "opens a datagram socket on 0.0.0.0 then calls succeed on the starter" do
      EventMachine.should_receive(:defer).and_yield
      EventMachine.should_receive(:open_datagram_socket).with(
        '0.0.0.0', 0, Pants::Writers::UDPWriterConnection, channel, ip, port
      ).and_return(true)
      EventMachine.should_receive(:tick_loop).and_yield.and_return(tick_loop)

      subject.start
    end
  end

  describe "#stop" do
    let(:connection) do
      c = double "EventMachine::Connection"
      c.should_receive(:close_connection_after_writing)

      c
    end

    let(:stopper) do
      s = double "EventMachine::DefaultDeferrable"
      s.should_receive(:succeed)

      s
    end

    before do
      subject.instance_variable_set(:@connection, connection)
      subject.stub(:stopper).and_return(stopper)
    end

    it "closes the socket and calls succeed on the stopper" do
      subject.stop
    end
  end
end

describe Pants::Writers::UDPWriterConnection do
  let(:channel) { double "EventMachine::Channel" }
  let(:port) { 1234 }

  describe "#initialize" do
    before do
      Pants::Writers::UDPWriterConnection.any_instance.stub(:post_init)
    end

    context "multicast IP address" do
      let(:ip) { '224.0.0.1' }

      it "sets up the socket to do multicast" do
        Pants::Writers::UDPWriterConnection.any_instance.
          should_receive(:setup_multicast_socket).with(ip)

        Pants::Writers::UDPWriterConnection.new(0, channel, ip, port)
      end
    end

    context "unicast IP address" do
      let(:ip) { '223.0.0.1' }

      it "does not set up the socket to do multicast" do
        Pants::Writers::UDPWriterConnection.any_instance.
          should_not_receive(:setup_multicast_socket)

        Pants::Writers::UDPWriterConnection.new(0, channel, ip, port)
      end
    end
  end
end
