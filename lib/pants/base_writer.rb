require 'eventmachine'
require_relative 'logger'


class Pants
  class BaseWriter

    # The block to be called when starting up a new Pants reader.
    attr_reader :starter

    # The block to be called when the reader is done reading.
    attr_reader :finisher

    def initialize
      unless @finisher
        warn "You haven't defined a finisher--are you sure you're cleaning up?"
      end

      unless @starter
        warn "You haven't defined a starter--are you sure this writer does something?"
      end
    end
  end
end