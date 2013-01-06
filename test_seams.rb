
require './lib/pants'

orig_file = 'dest_test_file'
seamed_file = 'dest_seamed_file'

Pants.read(orig_file) do |reader|
  ss = reader.add_seam(Pants::SimpleSeam)
  ss.add_writer(seamed_file)
end

if defined? orig_file
  seamed_file_size = File.stat(seamed_file).size
  orig_file_size = File.stat(orig_file).size
  puts "Seamed file size: #{seamed_file_size}"
  puts "Original file size: #{orig_file_size}"
  puts "Difference: #{orig_file_size - seamed_file_size}"
end