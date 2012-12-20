require 'eventmachine'
require 'ipaddr'
require_relative 'logger'


class Pants
  class UDPReceiveConnection < EventMachine::Connection
    include LogSwitch::Mixin

    attr_reader :data_channel

    def initialize(data_channel)
      @data_channel = data_channel
      port, ip = Socket.unpack_sockaddr_in(get_sockname)

      if Addrinfo.ip(ip).ipv4_multicast? || Addrinfo.ip(ip).ipv6_multicast?
        log "Got a multicast address: #{ip}:#{port}"
        setup_multicast_socket(ip)
      else
        log "Got a unicast address: #{ip}:#{port}"
      end
    end

    def receive_data(data)
      #log "<< #{data.size}"
      @data_channel << data
    end
  end

  class UDPReader
    include LogSwitch::Mixin

    attr_accessor :connection

    def initialize(data_channel, read_ip, read_port)
      log "Adding a #{self.class} at #{read_ip}:#{read_port}..."

      @connection = EM.open_datagram_socket(read_ip, read_port,
        UDPReceiveConnection, data_channel)
    end
  end
end
