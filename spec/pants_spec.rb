require 'spec_helper'
require "pants"

describe Pants do
  specify { Pants::VERSION.should == '0.1.0' }

  describe "#initialize" do
    it "should do some stuff" do
      pending "FIXME"
    end
  end
end
