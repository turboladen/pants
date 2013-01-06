require_relative 'base_writer'


class Pants
  module Writers

    # This is the interface for FileWriterConnections.  It controls starting,
    # stopping, and threading the connection.
    class FileWriter < BaseWriter
      include LogSwitch::Mixin

      # @param [EventMachine::Channel] read_from_channel The channel to read data
      #   from and thus write to file.
      #
      # @param [String] file_path The path to write to.
      def initialize(file_path, read_from_channel)
        @file = file_path.is_a?(File) ? file_path : File.open(file_path, 'w')
        @file_path = file_path

        super(read_from_channel)
      end

      def stop
        log "Finishing ID #{__id__} and closing file #{@file}"
        @file.close unless @file.closed?
        finisher.succeed
      end

      def start
        log "#{__id__} Adding a #{self.class} to write to #{@file_path}"

        EM.defer do
          @read_from_channel.subscribe do |data|
            begin
              @file.write_nonblock(data)
              log "Wrote normal"
            rescue IOError
              log "Finishing writing"
              File.open(@file, 'a') do |file|
                file.write_nonblock(data)
              end
            end
          end

          starter.succeed
        end
      end
    end
  end
end

