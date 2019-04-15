class URLHelper

  # FIXME: We'll do something better than this in production mode
  def self.cache_buster
    "?cb=#{SecureRandom.hex}"
  end

  def self.css(file)
    "/css/#{file}" + cache_buster
  end

  def self.js(file)
    "/js/#{file}" + cache_buster
  end

end
