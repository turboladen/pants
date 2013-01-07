require 'uri'
require 'eventmachine'
require_relative 'error'
require_relative 'logger'

Dir[File.dirname(__FILE__) + "/readers/*.rb"].each { |f| require f }
Dir[File.dirname(__FILE__) + "/writers/*.rb"].each { |f| require f }
require_relative 'seam'


class Pants
  class Core
    include LogSwitch::Mixin

    attr_reader :readers

    def initialize(&block)
      setup_signals
      @readers = []

      @convenience_block = block
    end

    # @param [String] id The URI to the object to read.  Can be a file:///,
    #   udp://, or an empty string for a file.
    #
    # @return [Pants::Reader] The newly created reader.
    def add_reader(id)
      callback = EM.Callback do
        if @readers.none?(&:running?)
          EM.stop_event_loop
        end
      end

      if id.is_a? String
        begin
          uri = URI(id)
        rescue URI::InvalidURIError
          @readers << new_reader_from_uri(nil, callback)
        else
          @readers << new_reader_from_uri(uri, callback)
        end
      elsif id.is_a? Symbol
        @readers << new_reader_from_symbol(id, callback)
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
    # @todo Merge this back to Readers
    def add_demuxer(uri_string, stream_id)
      callback = EM.Callback do
        if @readers.none?(&:running?)
          EM.stop_event_loop
        end
      end

      @readers << Pants::Readers::AVFileDemuxer.new(uri_string, stream_id, callback)

      if @convenience_block
        @convenience_block.call(@readers.last)
      end

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

        EM::Iterator.new(@readers).each do |reader, iter|
          reader.start
          iter.next
        end
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
    def stop!
      puts "Stop called.  Closing readers and writers..."
      #@readers.each { |reader| reader.finisher.set_deferred_success }
      if @readers.none?(&:running?)
        puts "No readers are running; nothing to do."
      else
        puts "Stopping readers:"

        @readers.each do |reader|
          puts "\t#{reader}" if reader.running?
        end

        @readers.each(&:stop!)
      end

    end

    # Stop, then run.
    def restart
      stop!
      puts "Restarting..."
      run
    end

    private

    # Register signals:
    # * TERM & QUIT calls +stop+ to shutdown gracefully.
    # * INT calls <tt>stop!</tt> to force shutdown.
    # * HUP calls <tt>restart</tt> to ... surprise, restart!
    def setup_signals
      @trapped_count ||= 0

      stopper = proc do
        @trapped_count += 1
        stop!

        # Reset count after 5 seconds
        EM.add_timer(5) { @trapped_count = 0 }
      end

      trap('INT')  do
        stopper.call
        abort "Multiple INT signals trapped; aborting!" if @trapped_count > 1
      end

      trap('TERM') { stopper.call }

      unless !!RUBY_PLATFORM =~ /mswin|mingw/
        trap('QUIT') { stop! }
        trap('HUP')  { restart }
      end
    end

    # @param [URI] uri The URI the Reader is mapped to.
    #
    # @return [Pants::Reader] An object of the type that's defined by the URI
    #   scheme.
    #
    # @raise [Pants::Error] If no Reader is mapped to +scheme+.
    def new_reader_from_uri(uri, callback)
      reader = if uri.nil?
        Pants.readers.find { |reader| reader[:uri_scheme].nil? }
      else
        Pants.readers.find { |reader| reader[:uri_scheme] == uri.scheme }
      end

      unless reader
        raise ArgumentError, "No reader found with URI scheme: #{uri.scheme}"
      end

      args = if reader[:args]
        reader[:args].map { |arg| uri.send(arg) }
      else
        []
      end

      reader[:klass].new(*args, callback)
    end

    def new_reader_from_symbol(symbol, callback)
      reader = Pants.readers.find { |reader| reader[:uri_scheme] == symbol }

      unless reader
        raise ArgumentError, "No reader found with URI scheme: #{symbol}"
      end

      args = if reader[:args]
        reader[:args].map { |arg| uri.send(arg) }
      else
        []
      end

      reader[:klass].new(*args, callback)
    end
  end
end