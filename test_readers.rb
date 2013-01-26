require_relative './lib/pants'


Pants.log = true

#EM.threadpool_size = 200
#EM.kqueue
#EM.epoll

orig_file = 'spec/support/pants.wav'
dest_file = 'dest_test_file'
#Pants.read('udp://127.0.0.1:1234') do |reader|
Pants.read(orig_file) do |reader|
  10.times do |i|
    reader.add_writer(dest_file)
    reader.add_writer("udp://127.0.0.1:#{1235 + i}")
  end
  reader.add_writer('udp://10.221.222.90:9000')
end

if defined? orig_file
  pants_file_size = File.stat(dest_file).size
  orig_file_size = File.stat(orig_file).size
  puts "Pants file size: #{pants_file_size}"
  puts "Original file size: #{orig_file_size}"
  puts "Difference: #{orig_file_size - pants_file_size}"
end

#==============
core = Pants::Core.new
udp_reader = core.read 'udp://127.0.0.1:1234'
udp_reader.write_to 'udp://127.0.0.1:1235'

udp_reader2 = core.add_reader(Pants::Readers::UDPReader, '127.0.0.1', 1234)
udp_reader2.add_writer(Pants::Writers::UDPWriter, '127.0.0.1', 1235)

udp_reader3 = Pants::Readers::UDPReader.new('127.0.0.1', 1234, core.callback)
udp_writer3 = Pants::Writers::UDPWriter.new('127.0.0.1', 1235, udp_reader3.write_to_channel)
core.add_reader(udp_reader3)
udp_reader3.add_writer(udp_writer3)

seam = udp_reader.add_seam(Pants::SimpleSeam)
seam.write_to 'my_file'
