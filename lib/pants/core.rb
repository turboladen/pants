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

    # One method of adding a Reader to the Core.  Use this method to make code
    # reader nicer when reading something that's expressed as a URI.
    #
    # @example
    #   core = Pants::Core.new
    #   core.read 'udp://10.2.3.4:9000'
    #
    # @param [String,URI] uri The URI to the object to read.  Can be a file:///,
    #   udp://, or a string with the path to a file.
    #
    # @return [Pants::Reader] The newly created reader.
    def read(uri)
      begin
        uri = uri.is_a?(URI) ? uri : URI(uri)
      rescue URI::InvalidURIError
        @readers << new_reader_from_uri(nil, callback)
      else
        @readers << new_reader_from_uri(uri, callback)
      end

      @convenience_block.call(@readers.last) if @convenience_block

      @readers.last
    end

    # One method of adding a Reader to the Core.  Use this method to add an
    # a) already instantiated Reader object, or b) a Reader from a class of
    # Reader objects.
    #
    # @example Add using class and init variables
    #   core = Pants::Core.new
    #   core.add_reader(Pants::Readers::UDPReader, '10.2.3.4', 9000)
    #
    # @example Add using an already instantiated Reader object
    #   core = Pants::Core.new
    #   reader = Pants::Readers::UDPReader.new('10.2.3.4', 9000, core.callback)
    #   core.add_reader(reader)
    #
    # Notice how using the last method requires you to pass in the core's
    # callback method--this is probably one reason for avoiding this method of
    # adding a reader, yet remains available for flexibility.
    #
    # @param [Class,Pants::Reader] obj Either the class of a Reader to create,
    #   or an already created Reader object.
    # @param [*] args Any arguments that need to be used for creating the
    #   Reader.
    def add_reader(obj, *args)
      if obj.is_a? Class
        @readers << obj.new(*args, callback)
      elsif obj.kind_of? Pants::Readers::BaseReader
        @readers << obj
      else
        raise Pants::Error, "Don't know how to add a reader of type #{obj}"
      end

      @convenience_block.call(@readers.last) if @convenience_block

      @readers.last
    end

    # Creates an EventMachine::Callback method that other Readers, Writers, and
    # others can use for letting the Core know when it can shutdown.  Those
    # Readers, Writers, etc. should handle calling this callback when they're
    # done doing what they need to do.
    #
    # @return [EventMachine::Callback]
    def callback
      EM.Callback do
        if @readers.none?(&:running?)
          EM.stop_event_loop
        end
      end
    end

    # Starts the EventMachine reactor, the reader and the writers.
    def run
      raise Pants::Error, "No readers added yet" if @readers.empty?

      starter = proc do
        puts "Pants v#{Pants::VERSION}"
        puts ">> Reading from #{@readers.size} readers"

        @readers.each_with_index do |reader, i|
          puts ">> reader#{i}:  Starting read on: #{reader.info}"
          puts ">> reader#{i}:  Writing to #{reader.writers.size} writers"

          reader.writers.each_with_index do |writer, j|
            puts ">> reader#{i}writer#{j}:  #{writer.write_object}"
          end
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
      reader_to_use = if uri.nil?
        Pants.readers.find { |reader| reader[:uri_scheme].nil? }
      else
        Pants.readers.find { |reader| reader[:uri_scheme] == uri.scheme }
      end

      unless reader_to_use
        raise ArgumentError, "No reader found with URI scheme: #{uri.scheme}"
      end

      args = if reader_to_use[:args]
        reader_to_use[:args].map { |arg| uri.send(arg) }
      else
        []
      end

      reader_to_use[:klass].new(*args, callback)
    end
  end
end
