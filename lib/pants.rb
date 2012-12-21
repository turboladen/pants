require 'uri'
require_relative 'pants/logger'
require_relative 'pants/file_reader'
require_relative 'pants/file_writer'
require_relative 'pants/udp_reader'
require_relative 'pants/udp_writer'
require_relative 'pants/version'


# Pants sort of mimics Linux's +splice+ command/call by taking a reader (the input) and
# redirects it to multiple writers (the outputs).
class Pants
  include LogSwitch::Mixin

  # Convenience method for doing:
  #
  #   pants = Pants.new('udp://0.0.0.0:1234') do |seam|
  #     # ...
  #   end
  #
  #   pants.run
  #
  # @param [String] uri Takes a URI ('udp://...' or 'file://...') or the path
  #   to a file.
  def self.read(uri, &block)
    new(uri, &block).run
  end

  attr_reader :reader
  attr_reader :writers

  # @param [String] uri_string The URI to the object to read.  Can be a file:///,
  #   udp://.
  def initialize(uri_string)
    @writers = []
    @data_channel = EM::Channel.new

    yield self if block_given?

    begin
      uri = URI(uri_string)
    rescue URI::InvalidURIError
      @reader = Pants::FileReader.new(@data_channel, uri_string)
    else
      @reader = case uri.scheme
      when nil
        Pants::FileReader.new(@data_channel, uri.path)
      when 'file'
        Pants::FileReader.new(@data_channel, uri.path)
      when 'udp'
        Pants::UDPReader.new(@data_channel, uri.host, uri.port)
      else
        raise ArgumentError, "Don't know what to do with reader: #{uri}"
      end
    end
  end

  # @param [String] uri_string The URI to the object to read.  Can be a file:///,
  #   udp://.
  def add_writer(uri_string)
    begin
      uri = URI(uri_string)
    rescue URI::InvalidURIError
      @writers << Pants::FileWriter.new(@data_channel, uri.path)
    else
      @writers << case uri.scheme
      when nil
        Pants::FileWriter.new(@data_channel, uri.path)
      when 'file'
        Pants::FileWriter.new(@data_channel, uri.path)
      when 'udp'
        Pants::UDPWriter.new(@data_channel, uri.host, uri.port)
      else
        raise ArgumentError, "Not sure what to do writer: #{uri}"
      end
    end
  end

  # Starts the EventMachine reactor
  def run
    starter = proc do
      puts "Pants v#{Pants::VERSION}"
      puts "Starting read on: #{@reader.info}"
      puts "Writing to #{@writers.size} writers"

      EM.next_tick do
        @reader.starter.call(@writers)
      end

      @writers.each { |writer| writer.starter.call }
    end

    if EM.reactor_running?
      log "Joining reactor..."
      starter.call
    else
      log "Starting reactor..."
      EM.run(&starter)
    end
  end
end
