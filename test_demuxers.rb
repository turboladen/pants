require './lib/pants'
require 'rtp/encoder'


Pants.log = true
RTP::Logger.log = true

av_file = '../effer/spec/support/sample_mpeg4_iTunes.mov'
raw_video_file = 'raw_video_file'
rtp_video_file = 'rtp_video_file'


Pants.demux(av_file, 0) do |demuxer|
  demuxer.add_writer(raw_video_file)
end

=begin
pants = Pants.new
demuxer = pants.add_demuxer(av_file, :video)

# Write all demuxed packets to a file
demuxer.add_writer(raw_video_file)

pants.run
=end


if defined? av_file
  raw_video_file_size = File.stat(raw_video_file).size
  orig_file_size = File.stat(av_file).size

  puts "Original file size: #{orig_file_size}"
  puts "Raw video file size: #{raw_video_file_size}"
  puts "Raw difference: #{orig_file_size - raw_video_file_size}"
end
