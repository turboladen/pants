require_relative 'pants/core'
require_relative 'pants/version'
Dir[File.dirname(__FILE__) + "/readers/*.rb"].each { |f| require f }
Dir[File.dirname(__FILE__) + "/writers/*.rb"].each { |f| require f }
require_relative 'pants/seam'

# Pants sort of mimics Linux's +splice+ command/call by taking a reader (the input) and
# redirects it to multiple writers (the outputs).
class Pants

  DEFAULT_READERS = [
    { uri_scheme: nil, klass: Pants::Readers::FileReader, args: [:path] },
    { uri_scheme: 'file', klass: Pants::Readers::FileReader, args: [:path] },
    { uri_scheme: 'udp', klass: Pants::Readers::UDPReader, args: [:host, :port] }
  ]

  DEFAULT_DEMUXERS = [
    { uri_scheme: nil, klass: Pants::Readers::AVFileDemuxer },
    { uri_scheme: 'file', klass: Pants::Readers::AVFileDemuxer }
  ]

  def self.readers
    @readers ||= DEFAULT_READERS
  end

  def self.demuxers
    @demuxers ||= DEFAULT_DEMUXERS
  end

  DEFAULT_WRITERS = [
    { uri_scheme: nil, klass: Pants::Writers::FileWriter, args: [:path] },
    { uri_scheme: 'udp', klass: Pants::Writers::UDPWriter, args: [:host, :port] }
  ]

  def self.writers
    @writers ||= DEFAULT_WRITERS
  end

  # Convenience method; doing something like:
  #
  #   pants = Pants::Core.new
  #   reader = pants.read('udp://0.0.0.0:1234')
  #   reader.add_writer('udp://1.2.3.4:5999')
  #   reader.add_writer('udp_data.raw')
  #   pants.run
  #
  # ...becomes:
  #
  #   Pants.read('udp://0.0.0.1234') do |seam|
  #     seam.add_writer('udp://1.2.3.4:5999')
  #     seam.add_writer('udp_data.raw')
  #   end
  #
  # @param [String] uri Takes a URI ('udp://...' or 'file://...') or the path
  #   to a file.
  def self.read(uri, &block)
    pants = Pants::Core.new(&block)

    if uri.kind_of? Pants::Readers::BaseReader
      pants.add_reader(uri)
    else
      pants.read(uri)
    end

    pants.run
  end

  # Convenience method; doing something like:
  #
  #   pants = Pants.new
  #   demuxer = pants.add_demuxer('my_movie.m4v')
  #   demuxer.add_writer('udp://1.2.3.4:5999')
  #   demuxer.add_writer('mpeg4_data.raw')
  #   pants.run
  #
  # ...becomes:
  #
  #   Pants.demux('my_movie.m4v') do |seam|
  #     seam.add_writer('udp://1.2.3.4:5999')
  #     seam.add_writer('mpepg4_data.raw')
  #   end
  #
  # @param [String] uri The path to the file to demux.
  # @param [Symbol,Fixnum] stream_id The ID of the stream in the file to
  #   extract.  Can be :video, :audio, or the actual stream index number.
  def self.demux(uri, stream_id, &block)
    pants = Pants::Core.new(&block)
    pants.add_demuxer(uri, stream_id)
    pants.run
  end



end
