require_relative 'pants/logger'
require_relative 'pants/file_reader'
require_relative 'pants/udp_reader'
require_relative 'pants/udp_writer'


# Pants sort of mimics Linux's +splice+ command/call by taking a reader (the input) and
# redirects it to multiple writers (the outputs).
class Pants
  include LogSwitch::Mixin
  attr_reader :reader
  attr_reader :writers

  def initialize(*args)
    @writers = []
    super()

    @starter = proc do
      @reader = case args.size
      when 1
        Pants::FileReader.new(args.first)
      when 2
        # Default socket... whatever that should be?
        Pants::UDPReader.new(ip, port)
      when 3
        # Specifying socket type
        ip, port, protocol = args
        Pants::UDPReader.new(ip, port) if protocol == :udp
      else
        raise ArgumentError
      end

      yield self if block_given?

      if @reader.is_a? Pants::FileReader
        @reader.connection.resume
      end
    end
  end

  def add_writer(*args)
    @writers << case args.size
    when 1
      # file
      abort "Not yet implemented for Files"
    when 2
      # Default socket
      ip, port = args
      Pants::UDPWriter.new(@reader.connection.data_channel, ip, port)
    when 3
      # Specifying socket type
      ip, port, protocol = args

      if protocol == :udp
        Pants::UDPWriter.new(@reader.connection.data_channel, ip, port)
      end
    else
      abort "Not sure what to do with these args: #{args}"
    end
  end

  def run
    if EM.reactor_running?
      log "Joining reactor..."
      @starter.call
    else
      log "Starting reactor..."
      EM.run(&@starter)
    end
  end
end
