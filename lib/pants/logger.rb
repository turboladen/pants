require 'log_switch'


class Pants
  extend LogSwitch
end

Pants.log_class_name = true
