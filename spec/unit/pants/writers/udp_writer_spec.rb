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
      s = double "starter"
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
end
