require 'uri'
require_relative 'pants/logger'
require_relative 'pants/version'

require_relative 'pants/av_file_demuxer'
require_relative 'pants/file_reader'
require_relative 'pants/udp_reader'

class Pants
  class Error < StandardError

  end
end

# Pants sort of mimics Linux's +splice+ command/call by taking a reader (the input) and
# redirects it to multiple writers (the outputs).
class Pants
  include LogSwitch::Mixin

  DEFAULT_READERS = [
      { uri_scheme: nil, klass: Pants::FileReader, args: [:path] },
      { uri_scheme: 'file', klass: Pants::FileReader, args: [:path] },
      { uri_scheme: 'udp', klass: Pants::UDPReader, args: [:host, :port] }
    ]

  DEFAULT_DEMUXERS = [
    { uri_scheme: nil, klass: Pants::AVFileDemuxer },
    { uri_scheme: 'file', klass: Pants::AVFileDemuxer }
  ]

  def self.readers
    @readers ||= DEFAULT_READERS
  end

  def self.demuxers
    @demuxers ||= DEFAULT_DEMUXERS
  end

  # @param [URI] uri The URI the Reader is mapped to.
  #
  # @return [Pants::Reader] An object of the type that's defined by the URI
  #   scheme.
  #
  # @raise [Pants::Error] If no Reader is mapped to +scheme+.
  def self.new_reader_from_uri(uri, write_to_channel=nil)
    reader = if uri.nil?
      readers.find { |reader| reader[:uri_scheme].nil? }
    else
      readers.find { |reader| reader[:uri_scheme] == uri.scheme }
    end

    unless reader
      raise ArgumentError, "No reader found with URI scheme: #{uri.scheme}"
    end

    args = reader[:args].map { |arg| uri.send(arg) }

    reader[:klass].new(*args, write_to_channel)
  end

  # Convenience method; doing something like:
  #
  #   pants = Pants.new
  #   reader = pants.add_reader('udp://0.0.0.0:1234')
  #   reader.add_writer('udp://1.2.3.4:5999')
  #   reader.add_writer('udp_data.raw')
  #   pants.run
  #
  # ...becomes:
  #
  #   Pants.read('udp://0.0.0.1234') do |seam|
  #     seam.add_writer('udp://1.2.3.4:5999')
  #     seam.add_writer('udp_data.raw')
  #   end
  #
  # @param [String] uri Takes a URI ('udp://...' or 'file://...') or the path
  #   to a file.
  def self.read(uri, &block)
    pants = new(&block)
    pants.add_reader(uri)
    pants.run
  end

  # Convenience method; doing something like:
  #
  #   pants = Pants.new
  #   demuxer = pants.add_demuxer('my_movie.m4v')
  #   demuxer.add_writer('udp://1.2.3.4:5999')
  #   demuxer.add_writer('mpeg4_data.raw')
  #   pants.run
  #
  # ...becomes:
  #
  #   Pants.demux('my_movie.m4v') do |seam|
  #     seam.add_writer('udp://1.2.3.4:5999')
  #     seam.add_writer('mpepg4_data.raw')
  #   end
  #
  # @param [String] uri The path to the file to demux.
  # @param [Symbol,Fixnum] stream_id The ID of the stream in the file to
  #   extract.  Can be :video, :audio, or the actual stream index number.
  def self.demux(uri, stream_id, &block)
    pants = new(&block)
    pants.add_demuxer(uri, stream_id)
    pants.run
  end

  attr_reader :readers

  def initialize(&block)
    setup_signals
    @readers = []

    @convenience_block = block
  end

  # @param [String] uri_string The URI to the object to read.  Can be a file:///,
  #   udp://, or an empty string for a file.
  #
  # @param [EventMachine::Channel] write_to_channel Optional custom channel to
  #   write to.  Readers create their own channel by default, so you don't need
  #   to give this unless you're getting creative.
  #
  # @return [Pants::Reader] The newly created reader.
  def add_reader(uri_string, write_to_channel=nil)
    begin
      uri = URI(uri_string)
    rescue URI::InvalidURIError
      @readers << Pants.new_reader_from_uri(nil, write_to_channel)
    else
      @readers << Pants.new_reader_from_uri(uri, write_to_channel)
    end

    if @convenience_block
      @convenience_block.call(@readers.last)
    end

    @readers.last
  end

  # @param [String] uri_string The URI to the object to read and demux.  Must be
  #   a path to a file.
  #
  # @return [Pants::Reader] The newly created reader.
  def add_demuxer(uri_string, stream_id)
    @readers << Pants::AVFileDemuxer.new(uri_string, stream_id)

    @readers.last
  end

  # Starts the EventMachine reactor, the reader and the writers.
  def run
    raise Pants::Error, "No readers added yet" if @readers.empty?

    starter = proc do
      puts "Pants v#{Pants::VERSION}"
      puts "Reader from #{@readers.size} readers"

      @readers.each_with_index do |reader, i|
        puts "Reader #{i + 1}:"
        puts "\tStarting read on: #{reader.info}"
        puts "\tWriting to #{reader.writers.size} writers"
      end

      @readers.each(&:start)
    end

    if EM.reactor_running?
      log "Joining reactor..."
      starter.call
    else
      log "Starting reactor..."
      EM.run(&starter)
    end
  end

  # Tells the reader to signal to its writers that it's time to finish.
  def stop
    puts "Stop called.  Closing readers and writers..."
    @readers.each { |reader| reader.finisher.set_deferred_success }
  end

  # Stop, then run.
  def restart
    stop
    puts "Restarting..."
    run
  end

  private

  # Register signals:
  # * TERM & QUIT calls +stop+ to shutdown gracefully.
  # * INT calls <tt>stop!</tt> to force shutdown.
  # * HUP calls <tt>restart</tt> to ... surprise, restart!
  # * USR1 reopen log files.
  def setup_signals
    trap('INT')  { stop }
    trap('TERM') { stop }

    unless !!RUBY_PLATFORM =~ /mswin|mingw/
      trap('QUIT') { stop }
      trap('HUP')  { restart }
    end
  end
end
