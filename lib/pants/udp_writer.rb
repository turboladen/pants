require 'eventmachine'
require_relative 'logger'


class Pants
  class UDPSender < EM::Connection
    include LogSwitch::Mixin

    def initialize(data_channel, dest_ip, dest_port)
      @data_channel = data_channel
      @dest_ip = dest_ip
      @dest_port = dest_port
    end

    def post_init
      @data_channel.subscribe do |data|
        log ">> #{data.size}"
        send_datagram(data, @dest_ip, @dest_port)
      end
    end
  end

  class UDPWriter
    include LogSwitch::Mixin

    def initialize(data_channel, write_ip, write_port)
      log "Adding a #{self.class} at #{write_ip}:#{write_port}..."

      EM.defer do
        @connection = EM.open_datagram_socket('0.0.0.0', 0, UDPSender, data_channel,
          write_ip, write_port)
      end
    end
  end
end
