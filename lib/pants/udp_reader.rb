require 'eventmachine'
require_relative 'logger'


class Pants
  class UDPReceiveConnection < EventMachine::Connection
    attr_reader :data_channel

    def initialize
      @data_channel = EM::Channel.new
    end

    def receive_data(data)
      @data_channel << data
    end
  end

  class UDPReader
    include LogSwitch::Mixin

    attr_accessor :connection

    def initialize(read_ip, read_port)
      log "Adding a #{self.class} at #{read_ip}:#{read_port}..."

      @connection = EM.open_datagram_socket(read_ip, read_port, UDPReceiveConnection)
    end
  end
end
