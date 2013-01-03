require 'eventmachine'
require_relative 'base_reader'
require_relative 'logger'

require 'effer/file_reader'
require 'ffi/libc'


class Pants

  # This is the interface for FileReaderConnections.  It controls starting and
  # stopping the connection.
  class AVFileDemuxer < BaseReader
    include LogSwitch::Mixin

    # @param [EventMachine::Channel] data_channel The channel to write to, so
    #   that all writers can do their thing.
    #
    # @param [String] file_path Path to the file to read.
    def initialize(data_channel, file_path, stream)
      super()

      @info = "#{file_path}:#{stream}"
      init_starter(data_channel, file_path, stream)
      @starter.call if EM.reactor_running?
    end

    private

    # Associates the list of writers (that should have already been created
    # already), opens the file, and starts demultiplexing it.
    #
    # @param [EventMachine::Channel] data_channel The channel to send read data
    #   to.
    #
    # @param [String] file_path The path to the file to read.
    #
    # @return [Proc] The code that should get called when Pants starts.
    def init_starter(data_channel, file_path, stream)
      reader = Effer::FileReader.new(file_path)

      @starter = proc do |writers|
        @writers = writers
        log "Opening and adding file at #{file_path}..."

        reader.dump_format
        video_stream = reader.streams.find { |stream| stream.type == :video }
        abort "No video stream found" unless video_stream

        EM.next_tick do
          video_stream.each_packet do |packet|
            data_channel << packet[:data].read_string(packet[:size])
          end
        end
      end
    end
  end
end