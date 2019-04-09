class Search

  SOLR_CHARS = '+-&|!(){}[]^"~*?:\\/ '

  def self.solr_escape(s)
    pattern = Regexp.quote(SOLR_CHARS)
    s.gsub(/([#{pattern}])/, '\\\\\1')
  end

  def self.build_keyword_query(s)
    s.split(' ').map {|subq| solr_escape(subq)}.join(' ')
  end

  def self.agency_typeahead(q)
    # FIXME: This sucks
    solr_url = AppConfig[:solr_url]

    unless solr_url.end_with?('/')
      solr_url += '/'
    end

    keyword_query = build_keyword_query(q)

    solr_query = "keywords:(#{keyword_query})^3 OR ngrams:#{solr_escape(q)}^1 OR edge_ngrams:#{solr_escape(q)}^2"

    uri = URI.join(solr_url, 'select')
    uri.query = URI.encode_www_form(q: solr_query, qt: 'json')

    request = Net::HTTP::Get.new(uri)

    Net::HTTP.start(uri.host, uri.port) do |http|
      response = http.request(request)

      # FIXME
      raise response.body unless response.code.start_with?('2')

      JSON.parse(response.body).fetch('response').fetch('docs').map {|hit| {'id' => hit.fetch('id'), 'label' => hit.fetch('display_string')}}
    end
  end

end
