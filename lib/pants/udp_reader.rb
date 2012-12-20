require 'eventmachine'
require 'socket'
require_relative 'logger'
require_relative 'network_helpers'


class Pants

  # This is the EventMachine connection that reads on the source IP and UDP
  # port.  It places all read data onto the data channel.  Allows for unicast or
  # multicast addresses; it'll detect which to use from the IP you pass in.
  class UDPReaderConnection < EventMachine::Connection
    include LogSwitch::Mixin
    include Pants::NetworkHelpers

    # @param [EventMachine::Channel] data_channel The data channel to write read
    #   data to.
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

    # Reads the data and writes it to the data channel.
    #
    # @param [String] data The socket data to write to the channel.
    def receive_data(data)
      @data_channel << data
    end
  end


  # This is the interface for UDPReaderConnections.  It controls what happens
  # when the you want to start it up and stop it.
  class UDPReader
    include LogSwitch::Mixin

    # @param [EventMachine::Channel] data_channel The channel to write to, so
    #   that all writers can do their thing.
    #
    # @param [String] read_ip The IP address to read on.
    #
    # @param [Fixnum] read_port The UDP port to read on.
    def initialize(data_channel, read_ip, read_port)
      super()

      init_starter(data_channel, read_ip, read_port)
      @starter.call if EM.reactor_running?
    end

    private

    # @param [EventMachine::Channel] data_channel The channel to write to, so
    #   that all writers can do their thing.
    #
    # @param [String] read_ip The IP address to read on.
    #
    # @param [Fixnum] read_port The UDP port to read on.
    def init_starter(data_channel, read_ip, read_port)
      @starter = proc do |writers|
        @writers = writers
        log "Adding a #{self.class} at #{read_ip}:#{read_port}..."
        EM.open_datagram_socket(read_ip, read_port, UDPReaderConnection,
          data_channel)
      end
    end
  end
end
