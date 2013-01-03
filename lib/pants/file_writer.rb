require 'eventmachine'
require_relative 'logger'


class Pants

  # This is the interface for FileWriterConnections.  It controls starting,
  # stopping, and threading the connection.
  class FileWriter
    include LogSwitch::Mixin

    # The block to be called when starting up a new Pants reader.
    attr_reader :starter

    # The block to be called when the reader is done reading.
    attr_reader :finisher

    # @param [EventMachine::Channel] read_from_channel The channel to read data
    #   from and thus write to file.
    #
    # @param [String] file_path The path to write to.
    def initialize(read_from_channel, file_path)
      file = file_path.is_a?(File) ? file_path : File.open(file_path, 'w')

      @starter = proc do
        log "#{__id__} Adding a #{self.class} to write to #{file_path}"

        EM.defer do
          read_from_channel.subscribe do |data|
            begin
              file.write_nonblock(data)
              log "Wrote normal"
            rescue IOError
              log "Finishing writing"
              File.open(file, 'a') do |file|
                file.write_nonblock(data)
              end
            end
          end
        end
      end

      @finisher = proc do
        log "Finishing ID #{__id__} and closing file #{file}"
        file.close unless file.closed?
      end

      @starter.call if EM.reactor_running?
    end
  end
end

