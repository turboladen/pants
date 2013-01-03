RSpec::Matchers.define :be_the_same_size_as do |expected|
  match do |actual|
    actual_size = File.stat(actual).size
    expected_size = File.stat(expected).size
    @difference = expected_size - actual_size
    @difference == 0
  end

  failure_message_for_should do |actual|
    "expected #{actual} to be the same size as #{expected}; diff: #{@difference}"
  end

  failure_message_for_should_not do |actual|
    "expected #{actual} to not be the same size as #{expected}"
  end

  description do
    "be the same size as #{expected}"
  end
end