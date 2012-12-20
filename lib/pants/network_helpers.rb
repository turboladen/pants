require 'ipaddr'
require 'socket'


class Pants
  module NetworkHelpers

    private

    # Sets Socket options to allow for multicasting.
    #
    # @param [String] ip The IP address to add to the multicast group.
    def setup_multicast_socket(ip)
      set_membership(::IPAddr.new(ip).hton + ::IPAddr.new('0.0.0.0').hton)
    end

    # @param [String] membership The network byte ordered String that represents
    #   the IP(s) that should join the membership group.
    def set_membership(membership)
      set_sock_opt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, membership)
    end
  end
end
