require 'eventmachine'
require 'socket'
require_relative 'base_reader'
require_relative '../network_helpers'


class Pants
  module Readers

    # This is the EventMachine connection that reads on the source IP and UDP
    # port.  It places all read data onto the data channel.  Allows for unicast or
    # multicast addresses; it'll detect which to use from the IP you pass in.
    class UDPReaderConnection < EventMachine::Connection
      include LogSwitch::Mixin
      include Pants::NetworkHelpers

      # @param [EventMachine::Channel] write_to_channel The data channel to write
      #   read data to.
      def initialize(write_to_channel, starter_deferrable)
        @write_to_channel = write_to_channel
        @starter_deferrable = starter_deferrable
        port, ip = Socket.unpack_sockaddr_in(get_sockname)

        if Addrinfo.ip(ip).ipv4_multicast? || Addrinfo.ip(ip).ipv6_multicast?
          log "Got a multicast address: #{ip}:#{port}"
          setup_multicast_socket(ip)
        else
          log "Got a unicast address: #{ip}:#{port}"
        end
      end

      def post_init
        @starter_deferrable.suceeded
      end

      # Reads the data and writes it to the data channel.
      #
      # @param [String] data The socket data to write to the channel.
      def receive_data(data)
        @write_to_channel << data
      end
    end


    # This is the interface for UDPReaderConnections.  It controls what happens
    # when the you want to start it up and stop it.
    class UDPReader < BaseReader
      include LogSwitch::Mixin

      # @param [String] read_ip The IP address to read on.
      #
      # @param [Fixnum] read_port The UDP port to read on.
      #
      # @param [EventMachine::Callback] core_stopper_callback The Callback that will get
      #   called when #stopper is called.  Since there is no clear end to when
      #   to stop reading this I/O, #stopper is never called internally; it must
      #   be called externally.
      def initialize(read_ip, read_port, core_stopper_callback)
        @read_object = "udp://#{read_ip}:#{read_port}"
        @read_ip = read_ip
        @read_port = read_port

        super(core_stopper_callback)
      end

      # Starts reading on the UDP IP and port and pushing packets to the channel.
      def start
        callback = EM.Callback do
          log "Adding a #{self.class} at #{@read_ip}:#{@read_port}..."
          EM.open_datagram_socket(@read_ip, @read_port, UDPReaderConnection,
            @write_to_channel, starter)
        end

        super(callback)
      end
    end
  end
end
