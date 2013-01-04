require_relative 'logger'


class Pants
  class BaseReader
    include LogSwitch::Mixin


    # The block to be called when starting up.  Writers should all have been
    # added before calling this; if writers are started after this, they won't
    # get the first bytes that are read (due to start-up time).
    attr_reader :starter

    # Allows for adding "about me" info, depending on the reader type.  This
    # info is printed out when Pants starts, so you know get confirmation of
    # what you're about to do.  If you don't define this in your reader, nothing
    # will be printed out.
    attr_reader :info

    attr_reader :writers

    attr_reader :write_to_channel

    def initialize(write_to_channel=nil)
      @writers = []
      @write_to_channel = write_to_channel || EM::Channel.new
      @info ||= ""
      init_starter unless @starter
    end

    # The callback that gets called when the Reader is done reading.  Tells all
    # of the associated writers to finish up.
    #
    # @return [EventMachine::DefaultDeferrable] The Deferrable that should get
    #   called by any Reader when it's done reading.
    def finisher
      finisher = EM::DefaultDeferrable.new

      finisher.callback do
        log "Got called back after finished reading.  Starting shutdown..."

        EM.next_tick do
          start_loop = EM.tick_loop do
            if @writers.none?(&:running?)
              :stop
            end
          end
          start_loop.on_stop { EM.stop_event_loop }

          log "Stopping writers for reader #{self.__id__}"
          EM::Iterator.new(@writers).each do |writer, iter|
            writer.stop
            iter.next
          end
        end
      end

      finisher
    end

    # Children should define this to say what should happen when Pants starts
    # running.
    #
    # @return [Proc] The code that should get called when Pants starts.
    def init_starter
      raise Pants::Error, "Readers must define a @starter"
    end

    # Starts all of the writers, then starts the reader.  This makes sure the
    # writers are all running and ready for data before the reader starts
    # sending data out.
    def start
      start_loop = EM.tick_loop do
        if @writers.all?(&:running?)
          :stop
        end
      end
      start_loop.on_stop { @starter.call }

      log "Starting writers for reader #{self.__id__}..."
      EM::Iterator.new(@writers).each do |writer, iter|
        writer.start
        iter.next
      end
    end

    # @param [String] id The URI to the object to read.  Can be a file:///,
    #   udp://.
    #
    # @return [Pants::Writer] The newly created writer.
    def add_writer(id, *args)
      if id.is_a? String
        begin
          uri = URI(id)
        rescue URI::InvalidURIError
          @writers << new_writer_from_uri(nil, @write_to_channel)
        else
          @writers << new_writer_from_uri(uri, @write_to_channel)
        end
      else
        @writers << new_writer_from_symbol(id, *args, @write_to_channel)
      end

      @writers.last
    end

    private

    def new_writer_from_uri(uri, read_from_channel)
      writer = if uri.nil?
        Pants.writers.find { |writer| writer[:uri_scheme].nil? }
      else
        Pants.writers.find { |writer| writer[:uri_scheme] == uri.scheme }
      end

      unless writer
        raise ArgumentError, "No writer found wth URI scheme: #{uri.scheme}"
      end

      args = if writer[:args]
        writer[:args].map { |arg| uri.send(arg) }
      else
        []
      end

      writer[:klass].new(*args, read_from_channel)
    end

    def new_writer_from_symbol(symbol, *args, read_from_channel)
      writer = Pants.writers.find { |writer| writer[:uri_scheme] == symbol }

      unless writer
        raise ArgumentError, "No writer found with URI scheme: #{symbol}"
      end

      writer[:klass].new(*args, read_from_channel)
    end
  end
end
