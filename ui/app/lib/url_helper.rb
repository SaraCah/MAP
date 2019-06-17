class URLHelper

  def self.cache_buster
      "?#{cb}"
  end

  def self.cb
    if MAPTheApp.production?
      "cb=#{MAPTheApp.cache_nonce}"
    else
      "cb=#{SecureRandom.hex}"
    end
  end

  def self.css(file)
    "/css/#{file}" + cache_buster
  end

  def self.js(file)
    "/js/#{file}" + cache_buster
  end

  def self.merge_params(existing_params, new_params)
    URI.encode_www_form(existing_params.merge(new_params))
  end

end
