class URLHelper

  def self.cache_buster
    if MAPTheApp.production?
      "?cb=#{MAPTheApp.cache_nonce}"
    else
      "?cb=#{SecureRandom.hex}"
    end
  end

  def self.css(file)
    "/css/#{file}" + cache_buster
  end

  def self.js(file)
    "/js/#{file}" + cache_buster
  end

end
