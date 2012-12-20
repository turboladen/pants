require 'eventmachine'
require 'ipaddr'
require_relative 'logger'


class Pants

  class UDPSender < EM::Connection
    include LogSwitch::Mixin

    def initialize(data_channel, dest_ip, dest_port)
      @data_channel = data_channel
      @dest_ip = dest_ip
      @dest_port = dest_port

      if Addrinfo.ip(@dest_ip).ipv4_multicast? || Addrinfo.ip(@dest_ip).ipv6_multicast?
        log "Got a multicast address: #{@dest_ip}:#{@dest_port}"
        setup_multicast_socket(@dest_ip)
      else
        log "Got a unicast address: #{@dest_ip}:#{@dest_port}"
      end
    end

    def post_init
      @data_channel.subscribe do |data|
        if data.size > 1500
          log "Got big data: #{data.size}.  Splitting..."
          io = StringIO.new(data)
          io.binmode

          begin
            Pants::Logger.log "#{io.__id__}: Spliced 500 bytes to socket packet"

            new_packet = io.read_nonblock(500)
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
  end

  class UDPWriter
    include LogSwitch::Mixin

    def initialize(data_channel, write_ip, write_port)
      log "Adding a #{self.class} at #{write_ip}:#{write_port}..."

      EM.defer do
        @connection = EM.open_datagram_socket('0.0.0.0', write_port, UDPSender, data_channel,
          write_ip, write_port)
      end
    end
  end
end
