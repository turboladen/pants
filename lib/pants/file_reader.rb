require 'eventmachine'
require_relative 'base_reader'
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
      log "<< #{data.size}"
      @data_channel << data
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

    # @param [EventMachine::Channel] data_channel The channel to write to, so
    #   that all writers can do their thing.
    #
    # @param [String] file_path Path to the file to read.
    def initialize(data_channel, file_path)
      super()

      init_starter(data_channel, file_path)
      @starter.call if EM.reactor_running?
    end

    private

    # Associates the list of writers (that should have already been created
    # already), opens the file, and starts reading it.
    #
    # @param [EventMachine::Channel] data_channel The channel to send read data
    #   to.
    #
    # @param [String] file_path The path to the file to read.
    #
    # @return [Proc] The code that should get called when Pants starts.
    def init_starter(data_channel, file_path)
      log "Opening file."
      file = File.open(file_path, 'r')

      @starter = proc do |writers|
        @writers = writers
        log "Opening and adding file at #{file_path}..."
        EM.attach(file, FileReaderConnection, data_channel, finisher)
      end
    end
  end
end
