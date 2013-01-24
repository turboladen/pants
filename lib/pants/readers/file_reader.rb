require 'eventmachine'
require_relative 'base_reader'


class Pants
  module Readers
    # This is the EventMachine connection that reads the source file and puts
    # the read data into the data channel so writers can write as they need to.
    class FileReaderConnection < EventMachine::Connection
      include LogSwitch::Mixin

      # @param [EventMachine::Channel] write_to_channel The data channel to write
      #   read data to.
      #
      # @param [EventMachine::Deferrable] stopper Gets set to succeeded when the
      #   file-to-read has been fully read.
      def initialize(write_to_channel, starter, stopper)
        @write_to_channel = write_to_channel
        @stopper = stopper
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
        @stopper.succeed
      end
    end


    # This is the interface for FileReaderConnections.  It controls starting and
    # stopping the connection.
    class FileReader < BaseReader
      include LogSwitch::Mixin

      # @return [String] Path to the file that's being read.
      attr_reader :file_path

      # @param [String] file_path Path to the file to read.
      #
      # @param [EventMachine::Callback] core_stopper_callback The Callback that will get
      #   called when #stopper is called.  #stopper is called when the whole
      #   file has been read and pushed to the channel.
      def initialize(file_path, core_stopper_callback)
        log "Initializing #{self.class} with file path '#{file_path}'"
        @info = file_path
        @file_path = file_path

        super(core_stopper_callback)
      end

      # Starts reading the file after all writers have been started.
      def start
        callback = EM.Callback do
          log "Opening and adding file '#{@file_path}'..."
          file = File.open(@file_path, 'r')
          EM.attach(file, FileReaderConnection, @write_to_channel, starter, stopper)
        end

        super(callback)
      end
    end
  end
end
