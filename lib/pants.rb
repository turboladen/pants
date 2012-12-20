require_relative 'pants/logger'
require_relative 'pants/file_reader'
require_relative 'pants/file_writer'
require_relative 'pants/udp_reader'
require_relative 'pants/udp_writer'


# Pants sort of mimics Linux's +splice+ command/call by taking a reader (the input) and
# redirects it to multiple writers (the outputs).
class Pants
  include LogSwitch::Mixin
  attr_reader :reader
  attr_reader :writers

  def initialize(*args)
    super()
    @writers = []
    @data_channel = EM::Channel.new

    yield self if block_given?

    @reader = case args.size
    when 1
      Pants::FileReader.new(@data_channel, args.first)
    when 2
      # Default socket... whatever that should be?
      Pants::UDPReader.new(@data_channel, ip, port)
    when 3
      # Specifying socket type
      ip, port, protocol = args
      protocol = protocol.to_s.downcase.to_sym
      Pants::UDPReader.new(@data_channel, ip, port) if protocol == :udp
    else
      raise ArgumentError
    end
  end

  def add_writer(*args)
    log "Args: #{args}"
    @writers << case args.size
    when 1
      # file
      Pants::FileWriter.new(@data_channel, args.first)
    when 2
      # Default socket
      ip, port = args
      Pants::UDPWriter.new(@data_channel, ip, port)
    when 3
      # Specifying socket type
      ip, port, protocol = args
      protocol = protocol.to_s.downcase.to_sym

      if protocol == :udp
        Pants::UDPWriter.new(@data_channel, ip, port)
      end
    else
      abort "Not sure what to do with these args: #{args}"
    end
  end

  def run
    if EM.reactor_running?
      log "Joining reactor..."
      @reader.starter.call
    else
      log "Starting reactor..."

      EM.run do
        @writers.each { |writer| writer.starter.call }
        @reader.starter.call(@writers)
      end
    end
  end
end
