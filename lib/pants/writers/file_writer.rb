require_relative 'base_writer'


class Pants
  module Writers

    # This is the interface for FileWriterConnections.  It controls starting,
    # stopping, and threading the connection.
    class FileWriter < BaseWriter
      include LogSwitch::Mixin

      # @return [String] The path to the file that's being written to.
      attr_reader :file_path

      # @param [EventMachine::Channel] read_from_channel The channel to read data
      #   from and thus write to file.
      #
      # @param [String] file_path The path to write to.
      def initialize(file_path, read_from_channel)
        @file = file_path.is_a?(File) ? file_path : File.open(file_path, 'w')
        @file_path = file_path
        @write_object = @file_path

        super(read_from_channel)
      end

      def stop
        log "Finishing ID #{__id__} and closing file #{@file}"
        @file.close unless @file.closed?
        stopper.call
      end

      def start
        log "#{__id__} Adding a #{self.class} to write to #{@file_path}"

        EM.defer do
          @read_from_channel.subscribe do |data|
            begin
              bytes_written = @file.write_nonblock(data)
              log "Wrote normal, #{bytes_written} bytes"
            rescue IOError
              log "Finishing writing; only wrote #{bytes_written}"

              unless bytes_written == data.size
                File.open(@file, 'a') do |file|
                  file.write_nonblock(data)
                end
              end
            end
          end

          start_loop = EM.tick_loop { :stop unless @file.closed? }
          start_loop.on_stop { starter.call }
        end
      end
    end
  end
end

