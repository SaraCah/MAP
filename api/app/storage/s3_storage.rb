# NOTE: This file appears in both as_cartography and the MAP.  We may want to
# pull these into a shared gem if they stay the same, but for now, any bugs
# fixed here need fixing there too.

require 'securerandom'
require 'net/http'
require 'tempfile'

class S3Storage

  def initialize(bucket_url)
    @bucket_url = bucket_url
  end

  def store(io, key = nil)
    key ||= SecureRandom.hex

    uri = uri_for_key(key)

    with_spooled_file(io) do |file_stream, length|
      request = Net::HTTP::Put.new(uri)
      request.body_stream = file_stream

      request['Content-Length'] = length.to_s
      request['Content-Type'] = 'application/octet-stream'

      response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request(request)
      end

      unless response.code == '200'
        raise S3StoreFailed.new("[%s] %s" % [response.code, response.body])
      end
    end

    key
  end

  def get_stream(key, &block)
    uri = uri_for_key(key)

    request = Net::HTTP::Get.new(uri)

    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      http.request(request) do |response|
        unless response.code == '200'
          raise S3GetFailed.new("[%s] %s" % [response.code, response.body])
        end

        response.read_body do |chunk|
          block.call(chunk)
        end
      end
    end
  end

  class S3StoreFailed < StandardError; end
  class S3GetFailed < StandardError; end

  private

  def uri_for_key(key)
    URI.join((@bucket_url + "/").gsub('/+', '/'), key)
  end

  def with_spooled_file(io)
    size = 0

    tempfile = Tempfile.new

    begin
      io.each(4096) do |chunk|
        size += chunk.length
        tempfile << chunk
      end

      tempfile.rewind
      yield tempfile, size
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

end
