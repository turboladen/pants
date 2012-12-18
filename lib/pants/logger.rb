require 'log_switch'


class Pants
  class Logger
    extend LogSwitch
  end
end

Pants::Logger.log_class_name = true
