require 'eventmachine'
require_relative 'base_reader'
require_relative 'logger'


class Pants

  # This is the EventMachine connection that reads the source file and puts
  # the read data into the data channel so writers can write as they need to.
  class FileReaderConnection < EventMachine::Connection
    include LogSwitch::Mixin

    # @param [EventMachine::Channel] write_to_channel The data channel to write
    #   read data to.
    #
    # @param [EventMachine::Deferrable] finisher Gets set to succeeded when the
    #   file-to-read has been fully read.
    def initialize(write_to_channel, starter, finisher)
      @write_to_channel = write_to_channel
      @finisher = finisher
      @starter = starter
    end

    def post_init
      @starter.succeed
    end

    # Reads the data and writes it to the data channel.
    #
    # @param [String] data The file data to write to the channel.
    def receive_data(data)
      log "<< #{data.size}"
      @write_to_channel << data
    end

    # Called when the file is done being read.
    def unbind
      log "Unbinding"
      @finisher.succeed
    end
  end


  # This is the interface for FileReaderConnections.  It controls starting and
  # stopping the connection.
  class FileReader < BaseReader
    include LogSwitch::Mixin

    # @param [String] file_path Path to the file to read.
    #
    # @param [EventMachine::Callback] main_callback The Callback that will get
    #   called when #finisher is called.  #finisher is called when the whole
    #   file has been read and pushed to the channel.
    def initialize(file_path, main_callback)
      log "file path #{file_path}"
      @info = file_path
      @file_path = file_path

      super(main_callback)
    end

    # Starts reading the file after all writers have been started.
    def start
      callback = EM.Callback do
        log "Opening and adding file at #{@file_path}..."
        file = File.open(@file_path, 'r')
        EM.attach(file, FileReaderConnection, @write_to_channel, starter, finisher)
      end

      super(callback)
    end
  end
end
