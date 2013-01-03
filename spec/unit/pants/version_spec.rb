require 'spec_helper'
require 'pants/version'


describe Pants do
  specify { Pants::VERSION.should == '0.1.0' }
end