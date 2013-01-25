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

      def initialize(read_from_channel)
        @running = false
        @read_from_channel = read_from_channel
        @starter = nil
        @stopper = nil
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
      # @return [EventMachine::Callback] The Callback that should get
      #   called.
      def starter
        @starter ||= EM.Callback { @running = true }
      end

      # This should get called with #succeed after the writer is done writing
      # out the data in its channel.
      #
      # @return [EventMachine::Callback] The Callback that should get
      #   called.
      def stopper
        @stopper ||= EM.Callback { @running = false }
      end

      def running?
        @running
      end
    end
  end
end
