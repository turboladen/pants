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
        log ">> #{data.size}"
        send_data(data)
      end
    end
  end

  class FileWriter
    include LogSwitch::Mixin

    def initialize(data_channel, file_path)
      log "Adding a #{self.class} at #{file_path}..."
      file = file_path.is_a?(File) ? file_path : File.open(file_path, 'w')

      EM.defer do
        @connection = EM.attach(file, FileWriterConnection, data_channel)
      end
    end
  end
end

