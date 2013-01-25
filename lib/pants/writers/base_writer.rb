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

      # @param [EventMachine::Channel] read_from_channel The channel that this
      #   writer should read from.
      def initialize(read_from_channel)
        @running = false
        @read_from_channel = read_from_channel
        @write_object ||= nil
        @starter = nil
        @stopper = nil
      end

      # This method must be redefined in a child class.  The reader that this
      # writer is tied to will call this before it starts reading.
      def start
        warn "You haven't defined a start method--are you sure this writer does something?"
      end

      # This method must be redefined in a child class.  The reader that this
      # writer is tied to will call this when it's done reading whatever it's
      # reading.
      def stop
        warn "You haven't defined a stop method--are you sure you're cleaning up?"
      end

      # @return [String] A String that identifies what the writer is writing to.
      #   This is simply used for displaying info to the user.
      def write_object
        if @write_object
          @write_object
        else
          warn "No write_object info has been defined for this writer."
        end
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

      # @return [Boolean] Is the Writer writing data?
      def running?
        @running
      end
    end
  end
end
