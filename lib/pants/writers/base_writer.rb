require 'eventmachine'
require_relative '../logger'
require_relative '../tee'


class Pants
  module Writers
    class BaseWriter

      # The block to be called when starting up a new Pants reader.
      attr_reader :starter

      # The block to be called when the reader is done reading.
      attr_reader :finisher

      def initialize(read_from_channel)
        @running = false
        @read_from_channel = read_from_channel
        start if EM.reactor_running?
      end

      def start
        warn "You haven't defined a start method--are you sure this writer does something?"
      end

      def stop
        warn "You haven't defined a stop method--are you sure you're cleaning up?"
      end

      def starter
        return @starter if @starter

        @starter = EM::DefaultDeferrable.new

        @starter.callback do
          @running = true
        end

        @starter
      end

      def finisher
        return @finisher if @finisher

        @finisher = EM::DefaultDeferrable.new

        @finisher.callback do
          @running = false
        end

        @finisher
      end

      def running?
        @running
      end
    end
  end
end