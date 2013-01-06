require_relative './lib/pants'


Pants.log = true

#EM.threadpool_size = 200
#EM.kqueue
#EM.epoll

orig_file = 'spec/support/pants.wav'
dest_file = 'dest_test_file'
#Pants.read('udp://127.0.0.1:1234') do |reader|
Pants.read(orig_file) do |reader|
  1.times do |i|
    reader.add_writer(dest_file)
    reader.add_writer("udp://127.0.0.1:#{1235 + i}")
  end

end

if defined? orig_file
  pants_file_size = File.stat(dest_file).size
  orig_file_size = File.stat(orig_file).size
  puts "Pants file size: #{pants_file_size}"
  puts "Original file size: #{orig_file_size}"
  puts "Difference: #{orig_file_size - pants_file_size}"
end
