require_relative '../logger'


class Pants
  module Readers
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

      # @param [EventMachine::Callback] main_callback This gets called when all
      #   reading is done and the writers have written out all their data.  It
      #   signals to the caller that the job of the reader is all done.  For
      #   first level readers (readers that are not Tees), this lets Pants check
      #   all existing Readers to see if they're done, so it can know when to stop
      #   the reactor.
      #
      def initialize(main_callback)
        @writers = []
        @write_to_channel = EM::Channel.new
        @main_callback = main_callback
        @info ||= ""
        @running = false

        start(main_callback) if EM.reactor_running?
      end

      # Starts all of the writers, then starts the reader.  Child readers must
      # call this to make sure the writers are all running and ready for data
      # before the reader starts pushing data onto its Channel.
      #
      # @param [EventMachine::Callback] callback Once all writers are up and
      #   running, this gets called, letting the caller know all Writers are up
      #   and running.  This should contain all code that the child Reader wants
      #   to execute on start.
      def start(callback)
        start_loop = EM.tick_loop do
          if @writers.empty? || @writers.all?(&:running?)
            :stop
          end
        end
        start_loop.on_stop { callback.call }

        log "Starting writers for reader #{self.__id__}..."
        EM::Iterator.new(@writers).each do |writer, iter|
          writer.start
          iter.next
        end
      end

      # Calls the reader's #finisher, thus forcing the reader to shutdown.  For
      # readers that intend to read a finite amount of data, the Reader should
      # call the #finisher when it's done; for readers that read a non-stop stream
      # (i.e. like an open socket), this gets called by OS signals (i.e. if you
      # ctrl-c).
      def stop!
        finisher.succeed
      end

      def running?
        @running
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

      #---------------------------------------------------------------------------
      # Protecteds
      #---------------------------------------------------------------------------
      protected

      # This is used internally by child Readers to signal that they're up and
      # running.  If implementing your own Reader, make sure to call this.
      def starter
        return @starter if @starter

        @starter = EM::DefaultDeferrable.new

        @starter.callback do
          @running = true
        end

        @starter
      end

      # The callback that gets called when the Reader is done reading.  Tells all
      # of the associated writers to finish up.
      #
      # @return [EventMachine::DefaultDeferrable] The Deferrable that should get
      #   called by any Reader when it's done reading.
      def finisher
        return @finisher if @finisher

        @finisher = EM::DefaultDeferrable.new

        @finisher.callback do
          log "Got called back after finished reading.  Starting shutdown..."

          # remove this next_tick?
          EM.next_tick do
            start_loop = EM.tick_loop do
              if @writers.empty? || @writers.none?(&:running?)
                :stop
              end
            end

            start_loop.on_stop do
              @running = false
              @main_callback.call
            end

            log "Stopping writers for reader #{self.__id__}"
            EM::Iterator.new(@writers).each do |writer, iter|
              writer.stop
              iter.next
            end
          end
        end

        @finisher
      end

      #---------------------------------------------------------------------------
      # Privates
      #---------------------------------------------------------------------------
      private

      # Creates a Writer based on the mapping defined in Pants.writers.
      #
      # @param [URI] uri The URI that defines the Writer.
      # @param [EventMachine::Channel] read_from_channel The channel that the
      #   Writer will read from.
      # @return [Pants::Writer] The newly created Writer.
      # @raise [ArgumentError] If Pants.writers doesn't contain a mapping for the
      #   URI to a Writer class.
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

      # Creates a Writer based on the mapping defined in Pants.writers.
      #
      # @param [Symbol] symbol The Symbol that defines the Writer.
      # @param [EventMachine::Channel] read_from_channel The channel that the
      #   Writer will read from.
      # @return [Pants::Writer] The newly created Writer.
      # @raise [ArgumentError] If Pants.writers doesn't contain a mapping for the
      #   URI to a Writer class.
      def new_writer_from_symbol(symbol, *args, read_from_channel)
        writer = Pants.writers.find { |writer| writer[:uri_scheme] == symbol }

        unless writer
          raise ArgumentError, "No writer found with URI scheme: #{symbol}"
        end

        writer[:klass].new(*args, read_from_channel)
      end
    end
  end
end
