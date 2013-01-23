require 'eventmachine'
require_relative '../logger'


class Pants
  module Writers

    # Provides conventions for creating your own writer that can stop and start
    # safely.
    #
    # You should also consider adding attr_readers/methods for attributes that
    # are differentiators from other writers of the same type.  This will allow
    # readers to more easily remove your writer from them.
    class BaseWriter

      # The block to be called when starting up a new Pants reader.
      attr_reader :starter

      # The block to be called when the reader is done reading.
      attr_reader :stopper

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

      # This should get called with #succeed after the writer is sure to be up
      # and running, ready for accepting data.
      #
      # @return [EventMachine::DefaultDeferrable] The Deferrable that should get
      #   called.
      # @todo Use Callback instead of DefaultDeferrable
      def starter
        return @starter if @starter

        @starter = EM::DefaultDeferrable.new

        @starter.callback do
          @running = true
        end

        @starter
      end

      # This should get caled with #succeed after the writer is done writing
      # out the data in its channel.
      #
      # @return [EventMachine::DefaultDeferrable] The Deferrable that should get
      #   called.
      # @todo Use Callback instead of DefaultDeferrable
      def stopper
        return @stopper if @stopper

        @stopper = EM::DefaultDeferrable.new

        @stopper.callback do
          @running = false
        end

        @stopper
      end

      def running?
        @running
      end
    end
  end
end
