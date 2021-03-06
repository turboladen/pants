require_relative '../logger'


class Pants
  module Readers
    class BaseReader
      include LogSwitch::Mixin

      # @return [Array] The list of Writers attached to the Reader.
      attr_reader :writers

      # @return [EventMachine::Channel] The channel that Writers should subscribe
      #   to.
      attr_reader :write_to_channel

      # @return [EventMachine::Callback] The callback from Core that should be
      #   called when the Reader is done reading.
      attr_reader :core_stopper_callback

      # @param [EventMachine::Callback] core_stopper_callback This gets called when all
      #   reading is done and the writers have written out all their data.  It
      #   signals to the caller that the job of the reader is all done.  For
      #   first level readers (readers that are not Tees), this lets Pants check
      #   all existing Readers to see if they're done, so it can know when to stop
      #   the reactor.
      #
      def initialize(core_stopper_callback)
        @writers = []
        @write_to_channel = EM::Channel.new
        @core_stopper_callback = core_stopper_callback
        @read_object ||= nil
        @starter = nil
        @stopper = nil
        @running = false
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

      # Calls the reader's #stopper, thus forcing the reader to shutdown.  For
      # readers that intend to read a finite amount of data, the Reader should
      # call the #stopper when it's done; for readers that read a non-stop stream
      # (i.e. like an open socket), this gets called by OS signals (i.e. if you
      # ctrl-c).
      def stop!
        stopper.call
      end

      # Allows for adding "about me" info, depending on the reader type.  This
      # info is printed out when Pants starts, so you know get confirmation of
      # what you're about to do.  If you don't define this in your reader, nothing
      # will be printed out.
      #
      # @return [String] A String that identifies what the reader is reading
      #   from.
      def read_object
        if @read_object
          @read_object
        else
          warn "No read_object info has been defined for this reader."
        end
      end

      # @return [Boolean]
      def running?
        @running
      end

      # @param [String] uri The URI to the object to read.  Can be of URI type
      #   that's defined in Pants.writers.
      #
      # @return [Pants::Writers::BaseWriter] The newly created writer.
      def write_to(uri)
        begin
          uri = uri.is_a?(URI) ? uri : URI(uri)
        rescue URI::InvalidURIError
          @writers << new_writer_from_uri(nil, @write_to_channel)
        else
          @writers << new_writer_from_uri(uri, @write_to_channel)
        end

        @writers.last
      end

      # One method of adding a Writer to the Reader.  Use this method to add an
      # a) already instantiated Writer object, or b) a Writers from a class of
      # Writer objects.
      #
      # @example Add using class and init variables
      #   core = Pants::Core.new
      #   core.read 'udp://10.2.3.4:9000'
      #   core.add_writer(Pants::Writers::UDPWriter, '10.5.6.7', 9000)
      #
      # @example Add using an already instantiated Writer object
      #   core = Pants::Core.new
      #   reader = core.read 'udp://10.2.3.4:9000'
      #   writer = Pants::Writers::UDPWriter.new('10.5.6.7', 9000, reader.write_to_channel)
      #   core.add_writer(writer)
      #
      # Notice how using the last method requires you to pass in the channel
      # that the reader is pushing data to--this is probably one reason for
      # avoiding this method of adding a writer, yet remains available for
      # flexibility.
      #
      # @param [Class,Pants::Reader] obj Either the class of a Writer to create,
      #   or an already created Writer object.
      #
      # @param [*] args Any arguments that need to be used for creating the
      #   Writer.
      def add_writer(obj, *args)
        if obj.is_a? Class
          @writers << obj.new(*args, @write_to_channel)
        elsif obj.kind_of?(Pants::Writers::BaseWriter) || obj.kind_of?(Pants::Seam)
          @writers << obj
        else
          raise Pants::Error, "Don't know how to add a writer of type #{obj.class}"
        end

        @writers.last
      end

      # Removes a writer object from the internal list of writers.
      #
      # @example Using URI
      #   reader.writers    # => [<Pants::Writers::FileWriter @file_path='./testfile'...>]
      #   reader.remove_writer('./testfile')
      #   reader.writers    # => []
      #
      # @example Using class and args as key/value pairs
      #   reader.writers    # => [<Pants::Writers::FileWriter @file_path='./testfile'...>]
      #   reader.remove_writer(Pants::Writers::FileWriter, file_path: './testfile')
      #   reader.writers    # => []
      #
      # @param [Class] obj Class of the writer to remove.
      #
      # @param [Hash] key_value_pairs Keys are methods to be called on each
      #   writer and will be checked to see if the return value from that method
      #   equals the given value.
      def remove_writer(obj, key_value_pairs=nil)
        if obj.is_a? Class
          @writers.delete_if do |writer|
            writer.is_a?(obj) &&
              key_value_pairs.all? { |k, v| writer.send(k) == v }
          end
        elsif obj.is_a? String
          writer = begin
            uri = obj.is_a?(URI) ? obj : URI(obj)
          rescue URI::InvalidURIError
            find_writer_from_uri(nil)
          else
            find_writer_from_uri(uri)
          end

          unless writer
            raise ArgumentError, "No writer found wth URI scheme: #{uri.scheme}"
          end

          key_value_pairs = if writer[:args]
            writer[:args].inject({}) do |result, arg|
              result[arg] = uri.send(arg)

              result
            end
          else
            {}
          end

          @writers.delete_if do |w|
            w.is_a?(writer[:klass]) &&
              key_value_pairs.all? { |k, v| w.send(k) == v }
          end
        end
      end

      # Allows for adding a Pants::Seam (or child) object to the reader's list
      # of internal writers.  For more info on Seams, see the docs for
      # Pants::Seam.
      #
      # @param [Pants::Seam] klass The class of the Pants::Seam object to
      #   create.
      #
      # @return [Pants::Seam] The seam that was just created.
      #
      # @see Pants::Seam
      def add_seam(klass, *args)
        @writers << klass.new(@core_stopper_callback, @write_to_channel, *args)

        @writers.last
      end

      #---------------------------------------------------------------------------
      # Protecteds
      #---------------------------------------------------------------------------
      protected

      # The block to be called when starting up.  Writers should all have been
      # added before calling this; if writers are started after this, they won't
      # get the first bytes that are read (due to start-up time).
      #
      # This is used internally by child Readers to signal that they're up and
      # running.  If implementing your own Reader, make sure to call this.
      def starter
        @starter ||= EM.Callback { @running = true }
      end

      # The callback that gets called when the Reader is done reading.  Tells all
      # of the associated writers to finish up.
      #
      # @return [EventMachine::Callback] The Callback that should get
      #   called by any Reader when it's done reading.
      def stopper
        return @stopper if @stopper

        @stopper = EM.Callback do
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
              puts ">> All done reading on '#{@read_object}'."
              @core_stopper_callback.call
            end

            log "Stopping writers for reader #{self.__id__}"
            EM::Iterator.new(@writers).each do |writer, iter|
              writer.stop
              iter.next
            end
          end
        end

        @stopper
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
        writer_to_use = find_writer_from_uri(uri)

        unless writer_to_use
          raise ArgumentError, "No writer found wth URI scheme: #{uri.scheme}"
        end

        args = if writer_to_use[:args]
          writer_to_use[:args].map { |arg| uri.send(arg) }
        else
          []
        end

        writer_to_use[:klass].new(*args, read_from_channel)
      end

      # @param [URI] uri The URI that defines the Writer.
      # @return [Hash] The Hash from Pants.writers that matches the URI.
      def find_writer_from_uri(uri)
        if uri.nil?
          Pants.writers.find { |writer| writer[:uri_scheme].nil? }
        else
          Pants.writers.find { |writer| writer[:uri_scheme] == uri.scheme }
        end
      end
    end
  end
end
