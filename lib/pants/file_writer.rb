require 'eventmachine'
require_relative 'logger'


class Pants
  class FileWriterConnection < EM::Connection
    include LogSwitch::Mixin

    def initialize(data_channel)
      @data_channel = data_channel
    end

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

    def unbind
      close_connection_after_writing
      log "Unbinding"
      @io.flush
    end
  end

  class FileWriter
    include LogSwitch::Mixin
    attr_reader :starter
    attr_reader :finisher

    def initialize(data_channel, file_path)
      file = file_path.is_a?(File) ? file_path : File.open(file_path, 'w')

      @starter = proc do
        log "Adding a #{self.class} at #{file_path}..."

        EM.defer do
          EM.attach(file, FileWriterConnection, data_channel)
        end
      end

      @finisher = proc do
        log "Finisher"
        file.close unless file.closed?
      end

      if EM.reactor_running?
        log "Reactor is runnning..."
        @starter.call
      end
    end
  end
end

