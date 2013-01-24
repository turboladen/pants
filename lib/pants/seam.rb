require_relative 'readers/base_reader'


class Pants
  class Seam < Pants::Readers::BaseReader
    include LogSwitch::Mixin

    attr_reader :channel_for_writers

    def initialize(core_stopper_callback, reader_channel)
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

      super(core_stopper_callback)
      send_data
    end

    def start(callback)
      super(callback)

      starter.succeed
    end

    # Make sure you call this (with super()) in your child to ensure read and
    # write queues are flushed.
    def stop
      log "Stopping..."
      log "receives #{@receives}"
      log "reads #{@reads}"
      log "writes #{@writes}"
      log "sends #{@sends}"

      finish_loop = EM.tick_loop do
        if @read_queue.empty? && @write_queue.empty?
          :stop
        end
      end

      finish_loop.on_stop { stopper.succeed }
    end

    # Call this to read data that was put into the read queue.  It yields one
    # "item" (however the data was put onto the queue) at a time.  It will
    # continually yield as there is data that comes in on the queue.
    #
    # @param [Proc] block The block to yield items from the reader to.
    # @yield [item] Gives one item off the read queue.
    def read_items(&block)
      processor = proc do |item|
        block.call(item)
        @reads += item.size
        @read_queue.pop(&processor)
      end

      @read_queue.pop(&processor)
    end

    # Call this after your Seam child has processed data and is ready to send it
    # to its writers.
    #
    # @param [Object] data
    def write(data)
      @write_queue << data
      @writes += data.size
    end

    private

    def send_data
      processor = proc do |data|
        @write_to_channel << data
        @sends += data.size
        @write_queue.pop(&processor)
      end

      @write_queue.pop(&processor)
    end
  end
end
