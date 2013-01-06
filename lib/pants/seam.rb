require_relative 'readers/base_reader'


class Pants
  class Seam < Pants::Readers::BaseReader
    include LogSwitch::Mixin

    attr_reader :channel_for_writers

    def initialize(main_callback, reader_channel)
      @read_queue = EM::Queue.new
      @write_queue = EM::Queue.new

      @receives = 0
      @reads = 0
      @writes = 0
      @sends = 0

      reader_channel.subscribe do |data|
        log "Got data on reader channel"
        @read_queue << data
        @receives += data.size
      end

      super(main_callback)
      send_data
    end

    def start(callback)
      super(callback)

      starter.succeed
    end

    def stop
      log "Stopping..."
      log "receives #{@receives}"
      log "reads #{@reads}"
      log "writes #{@writes}"
      log "sends #{@sends}"
      finisher.succeed
    end

    def read
      processor = proc do |item|
        puts "Got item of size #{item.size}"
        yield item
        @reads += item.size
        @read_queue.pop(&processor)
      end

      @read_queue.pop(&processor)
    end

    def write(data)
      @write_queue << data
      @writes += data.size
    end

    def finisher
      return @seam_finisher if @seam_finisher

      @seam_finisher = EM::DefaultDeferrable.new

      @seam_finisher.callback do
        super_finisher = super

        finish_loop = EM.tick_loop do
          if @read_queue.empty? && @write_queue.empty?
            :stop
          end
        end

        finish_loop.on_stop { super_finisher.succeed }
      end

      @seam_finisher
    end

    private

    def send_data
      processor = proc do |data|
        puts "Sending item of size #{data.size}"
        @write_to_channel << data
        @sends += data.size
        @write_queue.pop(&processor)
      end

      @write_queue.pop(&processor)
    end
  end
end


class Pants::SimpleSeam < Pants::Seam
  def start
    callback = EM.Callback do
      log "Starting simple seam..."
      read do |data|
        write data
      end
    end

    super(callback)
  end
end