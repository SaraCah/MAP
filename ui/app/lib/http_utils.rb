class HTTPUtils

  def self.sanitise_mime_type(s)
    # https://tools.ietf.org/html/rfc6838 sec 4.2
    s.to_s.split('/', 2).map {|segment|
                                segment.gsub(/\A[^a-zA-Z0-9]+/, '')
                                  .gsub(/[^a-zA-Z0-9!\#$&\-\^_+\.]/, '')
    }.join('/')
  end

end
