require 'eventmachine'
require_relative 'logger'


class Pants
  class FileReadConnection < EventMachine::Connection
    include LogSwitch::Mixin

    def initialize(data_channel, finisher)
      @data_channel = data_channel
      @finisher = finisher
    end

    def receive_data(data)
      @data_channel << data
    end

    def unbind
      log "Unbinding"
      @finisher.succeed
    end
  end

  class FileReader
    include LogSwitch::Mixin

    attr_reader :starter

    def initialize(data_channel, file_path)
      file = File.open(file_path, 'r')

      finisher = EM::DefaultDeferrable.new

      finisher.callback do
        log "Got called back after finished reading."

        EM.next_tick do
          @writers.each do |writer|
            writer.finisher.call
          end

          EM.stop_event_loop
        end
      end

      @starter = proc do |writers|
        @writers = writers
        log "Opening and adding file at #{file_path}..."
        EM.attach(file, FileReadConnection, data_channel, finisher)
      end

      if EM.reactor_running?
        @starter.call
      end
    end
  end
end
