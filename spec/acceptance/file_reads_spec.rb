require 'spec_helper'
require 'pants'


describe "File reads" do
  let(:original_file_path) do
    File.expand_path(File.dirname(__FILE__) + "/../support/pants.wav")
  end

  let(:dest_file_path) { 'acceptance_test_dest_file' }

  after do
    FileUtils.rm(dest_file_path)
  end

  it "reads from a file and copies all data to all other writer types" do
    Pants.read(original_file_path) do |reader|
      reader.add_writer(dest_file_path)
      reader.add_writer('udp://127.0.0.1:0')
    end

    original_file_path.should be_the_same_size_as dest_file_path
  end
end