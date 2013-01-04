require 'eventmachine'
require_relative 'base_reader'


class Pants
  class Tee < ::Pants::BaseReader
    def init_starter
      @starter = proc do
        log "Initing tee..."
      end
    end
  end
end