require 'eventmachine'
require_relative 'base_reader'
require 'effer/file_reader'


class Pants
  module Readers

    # This is the interface for FileReaderConnections.  It controls starting and
    # stopping the connection.
    class AVFileDemuxer < BaseReader
      include LogSwitch::Mixin

      attr_reader :codec_id
      attr_reader :codec_name
      attr_reader :frame_rate

      # @param [String] file_path Path to the file to read.
      #
      # @param [Symbol,Fixnum] stream_id Symbols are returned by
      #   Effer::Stream#type, so check docs there for candidates; typical choices
      #   are :video or :audio.  Can also be, more explicitly, the index of the
      #   stream as it is inside the file.
      #
      # @param [EventMachine::Callback] main_callback The Callback that will get
      #   called when #finisher is called.  #finisher is called when the while
      #   file has been demuxed and all packets have been pushed to the channel.
      def initialize(file_path, stream_id, main_callback)
        @info = "#{file_path}:#{stream_id}"
        init_stream(file_path, stream_id)

        @codec_id = @stream.codec_id
        @codec_name = @stream.codec_name
        @frame_rate = @stream.frame_rate

        super(main_callback)
      end

      # Associates the list of writers (that should have already been created
      # already), opens the file, and starts demultiplexing it.
      def start
        callback = EM.Callback do
          EM.next_tick do
            callback = proc { finisher.succeed }

            @stream.each_packet(callback) do |packet|
              @write_to_channel << packet[:data].read_string(packet[:size])
            end
          end
        end

        super(callback)
      end

      # @param [String] file_path The path to the file to read.
      #
      def init_stream(file_path, stream_id)
        reader = Effer::FileReader.new(file_path)
        reader.dump_format

        log "Opening and adding file at #{file_path}..."
        log "Looking for stream identified by: #{stream_id}"
        log "stream id is a #{stream_id.class}"

        @stream = if stream_id.is_a? Symbol
          reader.streams.find { |stream| stream.type == stream_id }
        elsif stream_id.is_a? Fixnum
          reader.streams.find { |stream| stream.index == stream_id }
        end
        abort "No video stream found" unless @stream

        log "Stream type: #{@stream.type}"
        log "Stream index: #{@stream.index}"
        log "Stream codec id: #{@stream.codec_id}"
        log "Stream codec name: #{@stream.codec_name}"
        log "Stream bit rate: #{@stream.av_stream.bit_rate}"
        log "Stream time base: #{@stream.time_base}"
        log "Stream frame rate: #{@stream.frame_rate}"
      end
    end
  end
end