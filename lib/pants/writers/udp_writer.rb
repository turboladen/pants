require 'socket'
require_relative 'base_writer'
require_relative '../network_helpers'


class Pants
  module Writers

    # This is the EventMachine connection that connects the data from the data
    # channel (put there by the reader you're using) to the IP and UDP port you
    # want to send it to.
    class UDPWriterConnection < EM::Connection
      include LogSwitch::Mixin
      include Pants::NetworkHelpers

      # Packets get split up before writing if they're over this size.
      PACKET_SPLIT_THRESHOLD = 1400

      # Packets get split up to this size before writing.
      PACKET_SPLIT_SIZE = 1300

      # @param [EventMachine::Channel] read_from_channel The channel to expect
      #   data on and write to the socket.
      #
      # @param [String] dest_ip The IP address to send data to.  Can be unicast
      #   or multicast.
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
              log "#{__id__} Spliced #{PACKET_SPLIT_SIZE} bytes to socket packet"

              while true
                new_packet = io.read_nonblock(PACKET_SPLIT_SIZE)
                send_datagram(new_packet, @dest_ip, @dest_port)
                new_packet = nil
              end
            rescue EOFError
              send_datagram(new_packet, @dest_ip, @dest_port) if new_packet
              io.close
            end
          else
            log "Sending data to #{@dest_ip}:#{@dest_port}"
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

      # @return [String] The IP address that's being written to.
      attr_reader :host

      # @return [Fixnum] The port that's being written to.
      attr_reader :port

      # @param [String] host
      #
      # @param [Fixnum] port
      #
      # @param [EventMachine::Channel] read_from_channel
      def initialize(host, port, read_from_channel)
        @host = host
        @port = port
        @connection = nil
        @write_object = "udp://#{@host}:#{@port}"

        super(read_from_channel)
      end

      # Readies the writer for data to write and waits for data to write.
      def start
        log "#{__id__} Adding a #{self.class} at #{@host}:#{@port}..."

        EM.defer do
          @connection = EM.open_datagram_socket('0.0.0.0', 0, UDPWriterConnection,
            @read_from_channel, @host, @port)

          start_loop = EM.tick_loop { :stop if @connection }
          start_loop.on_stop { starter.call }
        end
      end

      # Closes the connection and notifies the reader that it's done.
      def stop
        log "Finishing ID #{__id__}"
        @connection.close_connection_after_writing
        stopper.call
      end
    end
  end
end
