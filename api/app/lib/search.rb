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


  def self.query(hash)
    hash.map{|k,v| [k,'"'+v+'"'].join(':')}.join('&&')
  end


  def self.record_hash(record)
    {
      'uri' => record['uri'],
      'type' => record['primary_type'] == 'resource' ? 'Series' : 'Record',
      'title' => record['title'],
      'qsa_id' => record['qsa_id__u_sint'].first.to_s
    }
  end


  def self.controlled_records(agency_id)
    # FIXME: starting to feel modelly ... refactorme

    agency_uri = "/agents/corporate_entities/#{agency_id}"

    out = execute(query('responsible_agency_u_sstr' => agency_uri)).fetch('docs')
      .map{|record| record_hash(record) }

    # FIXME: hardcoded 90 days
    cutoff_date = Time.now() - (60*60*24 * 90)

    execute(query('recent_responsible_agencies_u_sstr' => agency_uri)).fetch('docs').map do |record|
      json = JSON.parse(record['json'])
      not_too_old = json['recent_responsible_agencies'].select{|rh|
        rh['ref'] == agency_uri && Time.new(*rh['end_date'].split('-')) >= cutoff_date
      }

      if not_too_old.length > 0
        # it is possible that this record passed in and out of this agency's control
        # more than once since the cutoff, so get the latest end_date
        latest_end_date = not_too_old.sort{|a,b| a['end_date'] <=> b['end_date']}.last['end_date']

        out << record_hash(record).merge('end_date' => latest_end_date)
      end
    end

    out
  end

end
