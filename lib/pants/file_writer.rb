require 'eventmachine'
require_relative 'logger'


class Pants

  # This is the "connection" (EventMachine term) that connects the data from
  # the data channel to the file to write to.
  class FileWriterConnection < EM::Connection
    include LogSwitch::Mixin

    # @param [EventMachine::Channel] data_channel The channel to expect data on
    #   and write to the file (self).
    def initialize(data_channel)
      @data_channel = data_channel
    end

    # Waits for data on the channel, then writes it out to file.
    def post_init
      @data_channel.subscribe do |data|
        begin
          @io.write_nonblock(data)
        rescue IOError
          File.open(@io, 'a') do |file|
            file.write_nonblock(data)
          end
        end
      end
    end

    # Makes sure the file is flushed before being closed.
    def unbind
      log "#{__id__} is unbinding"
      close_connection_after_writing
      @io.flush
    end
  end


  # This is the interface for FileWriterConnections.  It controls starting,
  # stopping, and threading the connection.
  class FileWriter
    include LogSwitch::Mixin

    # The block to be called when starting up a new Pants reader.
    attr_reader :starter

    # The block to be called when the reader is done reading.
    attr_reader :finisher

    # @param [EventMachine::Channel] data_channel The channel to read data from
    #   and thus write to file.
    #
    # @param [String] file_path The path to write to.
    def initialize(data_channel, file_path)
      file = file_path.is_a?(File) ? file_path : File.open(file_path, 'w')

      @starter = proc do
        log "#{__id__} Adding a #{self.class} to write to #{file_path}"

        EM.defer do
          EM.attach(file, FileWriterConnection, data_channel)
        end
      end

      @finisher = proc do
        log "Finishing ID #{__id__}"
        file.close unless file.closed?
      end

      if EM.reactor_running?
        @starter.call
      end
    end
  end
end

