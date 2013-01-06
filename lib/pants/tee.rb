require 'eventmachine'
require_relative 'readers/base_reader'


# TODO A Tee has to get added along with the list of writers so that it gets
# initialized before the reader starts.

class Pants
  class Tee < ::Pants::Readers::BaseReader
    def initialize
      callback = EM.Callback do
        log "Main callback called. (Does nothing for Tees)"
      end

      super(callback)
    end

    def start
      callback = EM.Callback do
        log "Initing tee..."
      end

      super(callback)
    end
  end
end