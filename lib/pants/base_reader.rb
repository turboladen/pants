class Pants
  class BaseReader

    # The block to be called when starting up.  Writers should all have been
    # added before calling this; if writers are started after this, they won't
    # get the first bytes that are read (due to start-up time).
    attr_reader :starter

    # Allows for adding "about me" info, depending on the reader type.  This
    # info is printed out when Pants starts, so you know get confirmation of
    # what you're about to do.  If you don't define this in your reader, nothing
    # will be printed out.
    attr_reader :info

    def initialize
      @writers = []
      @info = ""
    end

    # The callback that gets called when the Reader is done reading.  Tells all
    # of the associated writers to finish up.
    #
    # @return [EventMachine::DefaultDeferrable] The Deferrable that should get
    #   called by any Reader when it's done reading.
    def finisher
      finisher = EM::DefaultDeferrable.new

      finisher.callback do
        log "Got called back after finished reading."

        EM.next_tick do
          @writers.each do |writer|
            writer.finisher.call
          end

          EM.stop_event_loop
        end
      end

      finisher
    end

    # Children should define this to say what should happen when Pants starts
    # running.
    #
    # @return [Proc] The code that should get called when Pants starts.
    def init_starter
      warn "<#{self.class}> This should be defined by children."
    end
  end
end
