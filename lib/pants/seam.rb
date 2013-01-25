require_relative 'readers/base_reader'


class Pants

  # A Seam is a core Pants object type (like Readers and Writers) that lets you
  # attach to a Reader, work with the read data, and pass it on to attached
  # Writers.  It implements buffering by using EventMachine Queues: pop data
  # off the @read_queue, work with it, then push it onto the @write_queue.  Once
  # on the @write_queue, the Seam will pass on to all Writers that have been
  # added to it.
  #
  # The @read_queue is wrapped by #read_items, which yields data
  # chunks from the Reader in, allowing easy access to each bit of data as it
  # was when it was read in.  The @write_queue is wrapped by #write, which
  # lets you just give it the data you want to pass on to the attached Writers.
  #
  # Seams are particularly useful for working with network data, where if you're
  # redirecting traffic from one place to another, you may need to alter data
  # in those packets to make it useful to the receiving ends.
  class Seam < Pants::Readers::BaseReader
    include LogSwitch::Mixin

    # @return [EventMachine::Channel] The channel that Writers subscribe to.
    attr_reader :channel_for_writers

    # @param [EventMachine::Callback] core_stopper_callback The callback that's
    #   provided by Core.
    #
    # @param [EventMachine::Channel] reader_channel The channel from the Reader
    #   that the Seam is attached to.
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

      starter.call
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

      finish_loop.on_stop { stopper.call }
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
