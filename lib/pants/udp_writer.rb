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
        log ">> #{data.size}"
        send_datagram(data, @dest_ip, @dest_port)
      end
    end

    private

    # Sets Socket options to allow for multicasting.
    def setup_multicast_socket(ip)
      set_membership(::IPAddr.new(ip).hton + ::IPAddr.new('0.0.0.0').hton)
    end

    # @param [String] membership The network byte ordered String that represents
    #   the IP(s) that should join the membership group.
    def set_membership(membership)
      set_sock_opt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, membership)
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
