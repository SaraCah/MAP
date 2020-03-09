# NOTE: This file appears in both as_cartography and the MAP.  We may want to
# pull these into a shared gem if they stay the same, but for now, any bugs
# fixed here need fixing there too.
#
# ANOTHER NOTE: Here we're using the s3-sdk instead of regular REST requests
# because it turns out that doing straight up PUTs ends up creating objects
# owned by an "anonymous" user, and these can't be accessed through the AWS
# console.
#
# We'll migrate to using this class exclusively and it'll probably end up
# becoming s3_storage.rb over the next few weeks.

require 'securerandom'
require 'tempfile'
require 'aws-sdk-s3'

class S3AuthenticatedStorage

  def initialize(bucket = nil, region = nil, access_key = nil, secret_access_key = nil)
    @bucket = bucket || AppConfig[:storage_s3_bucket]
    @region = region || AppConfig[:storage_s3_region]
    @access_key = access_key || AppConfig[:storage_s3_access_key]
    @secret_access_key = secret_access_key || AppConfig[:storage_s3_secret_access_key]

    @fallback_ro_bucket = bucket || AppConfig[:storage_s3_bucket_fallback_ro]
  end

  def client
    Aws::S3::Client.new(:region => @region,
                        :credentials => Aws::Credentials.new(@access_key, @secret_access_key))
  end

  def store(io, key = nil)
    key ||= SecureRandom.hex

    begin
      with_spooled_file(io) do |file_stream, length|
        client.put_object(
          :body => file_stream,
          :bucket => @bucket,
          :key => key,
        )
      end
    rescue
      raise S3StoreFailed.new($!)
    end

    key
  end

  def get_stream(key, &block)
    candidate_keys = [key, key.downcase].uniq
    candidate_buckets = [@bucket, @fallback_ro_bucket].compact.uniq

    last_error = nil

    catch (:mainloop) do
      candidate_buckets.each do |bucket|
        candidate_keys.each do |key|
          begin
            client.get_object({
                                :bucket => bucket,
                                :key => key
                              },
                              &block)
            # Success!
            return
          rescue Aws::S3::Errors::NoSuchKey => e
            # Try the next key/bucket combo
            last_error = e
          rescue
            # Some other error.  Abort right away.
            last_error = $!
            throw :mainloop
          end
        end
      end
    end

    if last_error
      raise S3GetFailed.new(last_error)
    else
      raise S3GetFailed.new("Unexpected failure")
    end
  end

  def exists?(key)
    candidate_buckets.each do |bucket|
      candidate_keys.each do |key|
        begin
          client.head_object({
                               :bucket => @bucket,
                               :key => key
                             })

          return true
        rescue
          # Keep trying
        end
      end
    end

    return false
  end

  class S3StoreFailed < StandardError; end
  class S3GetFailed < StandardError; end

  private

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
