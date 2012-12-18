require 'eventmachine'
require_relative 'logger'


class Pants
  class FileReadConnection < EventMachine::Connection
    include LogSwitch::Mixin

    attr_reader :data_channel

    def initialize
      @data_channel = EM::Channel.new
    end

    def receive_data(data)
      log "<< #{data.size}"
      @data_channel << data
    end
  end

  class FileReader
    include LogSwitch::Mixin

    attr_reader :connection

    def initialize(file_path)
      @connection = if file_path.is_a? File
        log "Adding file #{file_path}..."

        EM.attach(file_path, FileReadConnection)
      elsif file_path.is_a? String
        log "Opening and adding file at #{file_path}..."

        file = File.open(file_path, 'r')
        EM.attach(file, FileReadConnection)
      end
    end
  end
end
