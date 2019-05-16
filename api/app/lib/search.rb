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


  def self.build_agency_filter(permissions)
    return "*:*" if permissions.is_admin
    return "id:(%s)" % [solr_escape(Ctx.get.current_location.agency.fetch('id'))]
  end


  def self.build_controlled_records_filter(permissions)
    return "*:*" if permissions.is_admin

    (_, aspace_agency_id) = Ctx.get.current_location.agency.fetch('id').split(':')

    return "responsible_agency:(\"%s\") OR recent_responsible_agency_filter:(\"%s\")" %
           [
             "/agents/corporate_entities/#{aspace_agency_id}",
             "/agents/corporate_entities/#{aspace_agency_id}_#{Date.today.strftime('%Y-%m-%d')}"
           ]
  end


  class SolrSearchFailure < StandardError; end


  def self.solr_handle_search(query_params)
    solr_url = AppConfig[:solr_url]

    unless solr_url.end_with?('/')
      solr_url += '/'
    end

    query_params = {qt: 'json'}.merge(query_params)

    search_uri = URI.join(solr_url, 'select')
    search_uri.query = URI.encode_www_form(query_params)

    request = Net::HTTP::Get.new(search_uri)

    Net::HTTP.start(search_uri.host, search_uri.port) do |http|
      response = http.request(request)

      raise SolrSearchFailure.new(response) unless response.code.start_with?('2')

      return JSON.parse(response.body).fetch('response').fetch('docs')
    end
  end


  def self.agency_typeahead(q, permissions)
    keyword_query = build_keyword_query(q)
    solr_query = "keywords:(#{keyword_query})^3 OR ngrams:#{solr_escape(q)}^1 OR edge_ngrams:#{solr_escape(q)}^2"

    solr_handle_search(q: solr_query, fq: build_agency_filter(permissions))
      .map {|hit| {'id' => hit.fetch('id'),
                   'label' => hit.fetch('title')}}
  end


  def self.representation_typeahead(q, permissions)
    keyword_query = build_keyword_query(q)

    solr_query = "keywords:(#{keyword_query})^3 OR ngrams:#{solr_escape(q)}^1 OR edge_ngrams:#{solr_escape(q)}^2"

    solr_handle_search(q: solr_query, fq: [build_controlled_records_filter(permissions), 'types:representation'])
      .map {|hit| {'id' => hit.fetch('id'),
                   'label' => hit.fetch('title')}}

  end


  def self.record_hash(record)
    record.merge({
                   'type' => record['primary_type'] == 'resource' ? 'Series' : 'Record',
                 })
  end


  def self.controlled_records(permissions)
    solr_handle_search(q: "*:*", fq: build_controlled_records_filter(permissions))
      .map {|result| record_hash(result)}
  end

end
