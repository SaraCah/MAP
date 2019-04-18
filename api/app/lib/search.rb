class Search

  SOLR_CHARS = '+-&|!(){}[]^"~*?:\\/ '

  def self.solr_url(path = false)
    unless @solr_url
      @solr_url = AppConfig[:solr_url]

      unless @solr_url.end_with?('/')
        @solr_url += '/'
      end
    end

    path ? URI.join(@solr_url, path) : @solr_url
  end


  def self.solr_escape(s)
    pattern = Regexp.quote(SOLR_CHARS)
    s.gsub(/([#{pattern}])/, '\\\\\1')
  end


  def self.build_keyword_query(s)
    s.split(' ').map {|subq| solr_escape(subq)}.join(' ')
  end


  def self.build_permissions_filter(permissions)
    return "*:*" if permissions.is_admin
    
    return "id:(%s)" % [solr_escape(Ctx.get.current_location.agency.id.agency.id)]
  end


  def self.agency_typeahead(q, permissions)
    # FIXME: This sucks
    solr_url = AppConfig[:solr_url]

    unless solr_url.end_with?('/')
      solr_url += '/'
    end

    keyword_query = build_keyword_query(q)

    solr_query = "keywords:(#{keyword_query})^3 OR ngrams:#{solr_escape(q)}^1 OR edge_ngrams:#{solr_escape(q)}^2"

    uri = URI.join(solr_url, 'select')
    uri.query = URI.encode_www_form(q: solr_query, qt: 'json', fq: build_permissions_filter(permissions))

    request = Net::HTTP::Get.new(uri)

    Net::HTTP.start(uri.host, uri.port) do |http|
      response = http.request(request)

      # FIXME
      raise response.body unless response.code.start_with?('2')

      JSON.parse(response.body).fetch('response').fetch('docs').map {|hit| {'id' => hit.fetch('id'),
                                                                            'label' => hit.fetch('display_string')}}
    end
  end


  def self.execute(query, permissions = false)
    uri = solr_url('select')

    query_hash = {q: query, qt: 'json'}
    query_hash[:fq] = build_permissions_filter(permissions) if permissions

    uri.query = URI.encode_www_form(query_hash)

    request = Net::HTTP::Get.new(uri)

    Net::HTTP.start(uri.host, uri.port) do |http|
      response = http.request(request)

      # FIXME too
      raise response.body unless response.code.start_with?('2')

      JSON.parse(response.body).fetch('response')
    end
  end


  def self.controlled_records(agency_id)
    agency_uri = "/agents/corporate_entities/#{agency_id}"

    execute('responsible_agency_u_sstr:"' + agency_uri + '"').fetch('docs')
      .map{|record| {'id' => record['id'], 'title' => record['title']}}
  end

end
