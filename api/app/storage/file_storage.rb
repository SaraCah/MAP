# NOTE: This file appears in both as_cartography and the MAP.  We may want to
# pull these into a shared gem if they stay the same, but for now, any bugs
# fixed here need fixing there too.

require 'fileutils'
require 'securerandom'

class FileStorage

  def initialize(basedir)
    @basedir = basedir

    FileUtils.mkdir_p(basedir)
  end

  def store(io, key = nil)
    key ||= SecureRandom.hex

    File.open(File.join(@basedir, key), "w") do |fh|
      io.each(4096) do |chunk|
        fh << chunk
      end
    end

    key
  end

  def get_stream(key, &block)
    File.open(File.join(@basedir, key), "r") do |fh|
      fh.each(4096) do |chunk|
        block.call(chunk)
      end
    end
  end

end
