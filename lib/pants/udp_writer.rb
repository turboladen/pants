require 'socket'
require_relative 'base_writer'
require_relative 'network_helpers'


class Pants

  # This is the EventMachine connection that connects the data from the data
  # channel (put there by the reader you're using) to the IP and UDP port you
  # want to send it to.
  class UDPWriterConnection < EM::Connection
    include LogSwitch::Mixin
    include Pants::NetworkHelpers

    # Packets get split up before writing if they're over this size.
    PACKET_SPLIT_THRESHOLD = 1500

    # Packets get split up to this size before writing.
    PACKET_SPLIT_SIZE = 500

    # @param [EventMachine::Channel] read_from_channel The channel to expect
    #   data on and write to the socket.
    #
    # @param [String] dest_ip The IP address to send data to.  Can be unicast or
    #   multicast.
    #
    # @param [Fixnum] dest_port The UDP port to send data to.
    def initialize(read_from_channel, dest_ip, dest_port)
      @read_from_channel = read_from_channel
      @dest_ip = dest_ip
      @dest_port = dest_port

      if Addrinfo.ip(@dest_ip).ipv4_multicast? || Addrinfo.ip(@dest_ip).ipv6_multicast?
        log "Got a multicast address: #{@dest_ip}:#{@dest_port}"
        setup_multicast_socket(@dest_ip)
      else
        log "Got a unicast address: #{@dest_ip}:#{@dest_port}"
      end
    end

    # Sends data received on the data channel to the destination IP and port.
    # Since data may have been put in to the channel by a File reader (and will
    # therefore be larger chunks of data than you'll want to send in a packet
    # over the wire), it will split packets into +PACKET_SPLIT_SIZE+ sized
    # packets before sending.
    def post_init
      @read_from_channel.subscribe do |data|
        if data.size > PACKET_SPLIT_THRESHOLD
          log "#{__id__} Got big data: #{data.size}.  Splitting..."
          io = StringIO.new(data)
          io.binmode

          begin
            log "#{__id__} Spliced 500 bytes to socket packet"
            new_packet = io.read_nonblock(PACKET_SPLIT_SIZE)
            send_datagram(new_packet, @dest_ip, @dest_port)
          rescue EOFError
            socket_sender.notify(new_packet)
            send_datagram(new_packet, @dest_ip, @dest_port)
            io.close
          end
        else
          send_datagram(data, @dest_ip, @dest_port)
        end
      end
    end

    def receive_data(data)
      log "Got data (should I?): #{data.size}, port #{@dest_port}, peer: #{get_peername}"
    end
  end


  # This is the interface to UDPWriterConnections.  It defines what happens
  # when you want to start it up and stop it.
  class UDPWriter < BaseWriter
    include LogSwitch::Mixin

    def initialize(write_ip, write_port, read_from_channel)
      connection = nil

      @starter = proc do
        log "#{__id__} Adding a #{self.class} at #{write_ip}:#{write_port}..."

        EM.defer do
          connection = EM.open_datagram_socket('0.0.0.0', 0, UDPWriterConnection,
            read_from_channel, write_ip, write_port)
        end
      end

      @finisher = proc do
        log "Finishing ID #{__id__}"
        connection.close_connection_after_writing
      end

      @starter.call if EM.reactor_running?
      super()
    end
  end
end
