require 'eventmachine'
require_relative 'logger'


class Pants

  # This is the EventMachine connection that reads the source file and puts
  # the read data into the data channel so writers can write as they need to.
  class FileReaderConnection < EventMachine::Connection
    include LogSwitch::Mixin

    # @param [EventMachine::Channel] data_channel The data channel to write read
    #   data to.
    #
    # @param [EventMachine::Deferrable] finisher Gets set to succeeded when the
    #   file-to-read has been fully read.
    def initialize(data_channel, finisher)
      @data_channel = data_channel
      @finisher = finisher
    end

    # Reads the data and writes it to the data channel.
    #
    # @param [String] data The file data to write to the channel.
    def receive_data(data)
      @data_channel << data
    end

    # Called when the file is done being read.
    def unbind
      log "Unbinding"
      @finisher.succeed
    end
  end


  # This is the interface for FileReaderConnections.  It controls starting,
  # stopping, and threading the connection.
  class FileReader
    include LogSwitch::Mixin

    # The block to be called when starting up.  Writers should all have been
    # added before calling this; if writers are started after this, they won't
    # get the first bytes that are read (due to start-up time).
    attr_reader :starter

    # @param [EventMachine::Channel] data_channel The channel to write to, so
    #   that all writers can do their thing.
    #
    # @param [String] file_path Path to the file to read.
    def initialize(data_channel, file_path)
      file = File.open(file_path, 'rb')

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

      @starter = proc do |writers|
        @writers = writers
        log "Opening and adding file at #{file_path}..."
        EM.attach(file, FileReaderConnection, data_channel, finisher)
      end

      if EM.reactor_running?
        @starter.call
      end
    end
  end
end
