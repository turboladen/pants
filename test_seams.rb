=begin
require './lib/pants'


class Pants::SimpleSeam < Pants::Seam
  def start
    callback = EM.Callback do
      log "Starting simple seam..."
      read do |data|
        write data
      end
    end

    super(callback)
  end
end


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

#-------------------------------------------------------------------------------
Pants.mix do |mixer|
  mixer.add_reader('udp://127.0.0.1:1234')
  mixer.add_reader('udp://127.0.0.1:1235')
  mixer.add_writer(seamed_file)
end

#-------------------------------------------------------------------------------
core = Pants::Core.new
gatherer = Pants::Gatherer.new

gatherer.add_reader('udp://127.0.0.1:1234')
gatherer.add_reader('udp://127.0.0.1:1235')

core.run
#-------------------------------------------------------------------------------
=end
require './lib/pants'

class PantsInspector < Pants::Seam
  def initialize(core_callback, reader_channel, host)
    @host = host

    super(core_callback, reader_channel)
  end

  # Pants will call this for you when it starts the reader that the seam is
  # reading from.
  def start

    # You need to define a callback here so pants can call you back after its
    # made sure that the seam's writers have been started.  This makes sure
    # the seam doesn't start reading and pushing out data before the writers
    # are ready to receive it.
    callback = EM.Callback do
      puts "Starting #{self.class}..."

      read_items do |data|
        if data.match(/pants/mi)
          data << "Pants party at #{@host}!!!!!!\n"
        end

        write data
      end
    end

    super(callback)
  end
end

# Assuming you have data coming in on this IP and UDP port, this reads each
# packet and hands it over to its writers--in this case, the file dump file
# writer, the UDP writer that sends to 10.0.0.50:9001, and our PacketInspector
# seam.
Pants.read(__FILE__) do |reader|

  # Dump UDP packets to a file
  reader.write_to 'file_dump_of_udp_packets.udp'

  # Redirect the UDP packets to another host
  reader.write_to 'udp://127.0.0.1:9001'

  # Inspect the UDP packets and notify about the party going on
  pants_inspector = reader.add_seam(PantsInspector, 'localhost')

  # The packet inspector seam behaves like a reader, which lets writers read
  # from it.  Dump those party packets to a file
  pants_inspector.write_to 'file_dump_of_party_packets.party'

  # Forward our partying packets on to another host.
  pants_inspector.write_to 'udp://127.0.0.1:9002'
end

