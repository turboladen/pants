require 'eventmachine'
require_relative 'base_reader'


class Pants
  module Readers
    class PipeReaderConnection < EventMachine::Connection
      include LogSwitch::Mixin

      # @param [EventMachine::Channel] write_to_channel The channel to write
      #   output from the command to.
      #
      # @param [EventMachine::Callback] starter Gets called when the connection
      #   has been fully initialized.
      #
      # @param [EventMachine::Callback] stopper Gets called when the command is
      #   done running.
      def initialize(write_to_channel, starter, stopper)
        @write_to_channel = write_to_channel
        @starter = starter
        @stopper = stopper
      end

      def post_init
        @starter.call
      end

      def receive_data(data)
        log "got data: #{data}"
        @write_to_channel << data
      end

      def unbind
        log "Unbinding..."
        @stopper.call
      end
    end


    class PipeReader < BaseReader
      include LogSwitch::Mixin

      # @param [String] command The command to run.
      #
      # @param [EventMachine::Callback] core_stopper_callback The Callback that
      #   will get called when #stopper is called.
      def initialize(command, core_stopper_callback)
        @read_object = command
        @command = command

        super(core_stopper_callback)
      end

      def start
        callback = EM.Callback do
          log "Adding a #{self.class} to run: #{@command}"
          EM.popen(@command, PipeReaderConnection, @write_to_channel, starter, stopper)
        end

        super(callback)
      end
    end
  end
end
