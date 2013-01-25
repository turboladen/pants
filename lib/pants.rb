require_relative 'pants/core'
require_relative 'pants/version'
Dir[File.dirname(__FILE__) + "/readers/*.rb"].each { |f| require f }
Dir[File.dirname(__FILE__) + "/writers/*.rb"].each { |f| require f }
require_relative 'pants/seam'


# This base class provides some helpers for doing quick, non-complex reading
# and writing.  Check docs on readers and writers for more information.
class Pants

  DEFAULT_URI_TO_READER_MAP = [
    { uri_scheme: nil, klass: Pants::Readers::FileReader, args: [:path] },
    { uri_scheme: 'file', klass: Pants::Readers::FileReader, args: [:path] },
    { uri_scheme: 'udp', klass: Pants::Readers::UDPReader, args: [:host, :port] }
  ]

  DEFAULT_URI_TO_WRITER_MAP = [
    { uri_scheme: nil, klass: Pants::Writers::FileWriter, args: [:path] },
    { uri_scheme: 'file', klass: Pants::Writers::FileWriter, args: [:path] },
    { uri_scheme: 'udp', klass: Pants::Writers::UDPWriter, args: [:host, :port] }
  ]

  # The list of mappings of URIs to Reader class types.  These mappings allow
  # Pants to look up the URI scheme and find what type of object should be
  # created when creating a Reader by giving it a URI.  It also defines the
  # arguments that the Reader class takes; these should Symbols that represent
  # names of methods that can be called on objects of the URI type.
  #
  # You can register new mappings here by pushing new mappings to the list.
  # Mappings should be in the form:
  #   { uri_scheme: 'my_scheme', klass: MyReaderClass, args: [:arg] }
  #
  # Note that if you're wanting to add to this list, and URI doesn't recognize
  # the URI scheme that you're adding for, you'll need to define that within
  # URI.  An example is given here: http://www.ruby-doc.org/stdlib-1.9.3/libdoc/uri/rdoc/URI.html
  #
  # If you want to use your own reader but don't want to go through all of this
  # hassle, you can add your reader using a different method.  See the docs for
  # Pants::Core for more info.
  #
  # @return [Array<Hash>] The list of mappings.
  def self.readers
    @readers ||= DEFAULT_URI_TO_READER_MAP
  end

  # The list of mappings of URIs to Writer class types.  See the docs for
  # .readers for more info.
  #
  # @return [Array<Hash>] The list of mappings.
  # @see Pants.readers
  def self.writers
    @writers ||= DEFAULT_URI_TO_WRITER_MAP
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
end
