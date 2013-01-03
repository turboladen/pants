require 'uri'
require_relative 'pants/av_file_demuxer'
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

  DEFAULT_READERS = [
      { uri_scheme: nil, klass: Pants::FileReader },
      { uri_scheme: 'file', klass: Pants::FileReader },
      { uri_scheme: 'udp', klass: Pants::UDPReader }
    ]

  DEFAULT_DEMUXERS = [
    { uri_scheme: nil, klass: Pants::AVFileDemuxer },
    { uri_scheme: 'file', klass: Pants::AVFileDemuxer }
  ]

  DEFAULT_WRITERS = [
    { uri_scheme: nil, klass: Pants::FileWriter },
    { uri_scheme: 'udp', klass: Pants::UDPWriter }
  ]

  def self.readers
    @readers ||= DEFAULT_READERS
  end

  def self.demuxers
    @demuxers ||= DEFAULT_DEMUXERS
  end

  def self.writers
    @writers ||= DEFAULT_WRITERS
  end

  # Convenience method; doing something like:
  #
  #   pants = Pants.new
  #   pants.add_reader('udp://0.0.0.0:1234')
  #   pants.add_writer('udp://1.2.3.4:5999')
  #   pants.add_writer('udp_data.raw')
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
  #   pants.add_demuxer('my_movie.m4v')
  #   pants.add_writer('udp://1.2.3.4:5999')
  #   pants.add_writer('mpeg4_data.raw')
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

  def self.new_reader_from_uri_scheme(scheme, *args)
    reader = readers.find { |reader| reader[:uri_scheme] == scheme }
    reader[:klass].new(*args)
  end

  def self.new_writer_from_uri_scheme(scheme, *args)
    writer = writers.find { |writer| writer[:uri_scheme] == scheme }
    writer[:klass].new(*args)
  end

  attr_reader :reader
  attr_reader :writers

  def initialize
    setup_signals
    @writers = []
    @data_channel = EM::Channel.new

    yield self if block_given?
  end

  # @param [String] uri_string The URI to the object to read.  Can be a file:///,
  #   udp://, or an empty string for a file.
  def add_reader(uri_string)
    begin
      uri = URI(uri_string)
    rescue URI::InvalidURIError
      @reader = Pants.new_reader_from_uri_scheme(nil, @data_channel, uri_string)
    else
      @reader = case uri.scheme
      when nil
        Pants.new_reader_from_uri_scheme(nil, @data_channel, uri.path)
      when 'file'
        Pants.new_reader_from_uri_scheme(nil, @data_channel, uri.path)
      when 'udp'
        Pants.new_reader_from_uri_scheme('udp', @data_channel, uri.host, uri.port)
      else
        raise ArgumentError, "Don't know what to do with reader: #{uri}"
      end
    end
  end

  # @param [String] uri_string The URI to the object to read and demux.  Must be
  #   a path to a file.
  def add_demuxer(uri_string, stream_id)
    @reader = Pants::AVFileDemuxer.new(@data_channel, uri_string, stream_id)
  end

  # @param [String] uri_string The URI to the object to read.  Can be a file:///,
  #   udp://.
  def add_writer(uri_string)
    begin
      uri = URI(uri_string)
    rescue URI::InvalidURIError
      @writers << Pants.new_writer_from_uri_scheme(nil, @data_channel, uri.path)
    else
      @writers << case uri.scheme
      when nil
        Pants.new_writer_from_uri_scheme(nil, @data_channel, uri.path)
      when 'file'
        Pants.new_writer_from_uri_scheme(nil, @data_channel, uri.path)
      when 'udp'
        Pants.new_writer_from_uri_scheme('udp', @data_channel, uri.host, uri.port)
      else
        raise ArgumentError, "Not sure what to do writer: #{uri}"
      end
    end
  end

  # Starts the EventMachine reactor, the reader and the writers.
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

  # Tells the reader to signal to its writers that it's time to finish.
  def stop
    puts "Stop called.  Closing readers and writers..."
    @reader.finisher.set_deferred_success
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
