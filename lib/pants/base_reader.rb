require_relative 'file_writer'
require_relative 'udp_writer'


class Pants
  class BaseReader

    DEFAULT_WRITER_TYPES = [
      { uri_scheme: nil, klass: Pants::FileWriter, args: [:path] },
      { uri_scheme: 'udp', klass: Pants::UDPWriter, args: [:host, :port] }
    ]

    def self.writer_types
      @writer_types ||= DEFAULT_WRITER_TYPES
    end

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
      @info = ""
    end

    # The callback that gets called when the Reader is done reading.  Tells all
    # of the associated writers to finish up.
    #
    # @return [EventMachine::DefaultDeferrable] The Deferrable that should get
    #   called by any Reader when it's done reading.
    def finisher
      finisher = EM::DefaultDeferrable.new

      finisher.callback do
        log "Got called back after finished reading."

        EM.next_tick do
          @writers.each do |writer|
            writer.finisher.call
          end

          EM.stop_event_loop
        end
      end

      finisher
    end

    # Children should define this to say what should happen when Pants starts
    # running.
    #
    # @return [Proc] The code that should get called when Pants starts.
    def init_starter
      warn "<#{self.class}> This should be defined by children."
    end

    # @param [String] uri_string The URI to the object to read.  Can be a file:///,
    #   udp://.
    def add_writer(uri_string)
      begin
        uri = URI(uri_string)
      rescue URI::InvalidURIError
        @writers << new_writer_from_uri(nil, @write_to_channel)
      else
        @writers << new_writer_from_uri(uri, @write_to_channel)
      end
    end

    def start
      EM.next_tick do
        @starter.call
      end

      log "Starting writers..."
      @writers.each { |writer| writer.start }
    end

    private

    def new_writer_from_uri(uri, read_from_channel)
      writer = if uri.nil?
        self.class.writer_types.find { |writer| writer[:uri_scheme].nil? }
      else
        self.class.writer_types.find { |writer| writer[:uri_scheme] == uri.scheme }
      end

      unless writer
        raise ArgumentError, "No writer found wth URI scheme: #{uri.scheme}"
      end

      args = writer[:args].map { |arg| uri.send(arg) }

      writer[:klass].new(*args, read_from_channel)
    end
  end
end
