require 'csv'

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
    return "primary_type:agent_corporate_entity" if permissions.is_admin
    return "id:(%s)" % [solr_escape(Ctx.get.current_location.agency.fetch('id'))]
  end


  def self.build_controlled_records_filter(permissions, agency_ref = nil)
    return "*:*" if permissions.is_admin

    aspace_agency_id = nil

    if agency_ref.nil?
      (_, aspace_agency_id) = Ctx.get.current_location.agency.fetch('id').split(':')
    else
      (_, aspace_agency_id) = agency_ref.split(':')
    end

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

    query_params = {'qt' => 'json'}.merge(query_params)
    query_params = {'rows' => AppConfig[:page_size]}.merge(query_params)

    search_uri = URI.join(solr_url, 'select')
    search_uri.query = URI.encode_www_form(query_params)

    request = Net::HTTP::Get.new(search_uri)

    Net::HTTP.start(search_uri.host, search_uri.port) do |http|
      response = http.request(request)

      raise SolrSearchFailure.new(response) unless response.code.start_with?('2')

      return JSON.parse(response.body)
    end
  end


  def self.record_hash(record, agency_ref = nil)
    aspace_agency_id = nil

    if agency_ref.nil?
      (_, aspace_agency_id) = Ctx.get.current_location.agency.fetch('id').split(':')
    else
      (_, aspace_agency_id) = agency_ref.split(':')
    end

    this_agency_uri = "/agents/corporate_entities/#{aspace_agency_id}"

    record.merge({
                   'under_movement' => record['responsible_agency'] != this_agency_uri,
                 })
  end


  def self.date_pad_start(s)
    default = ['0000', '01', '01']
    bits = s.split('-')

    full_date = (0...3).map {|i| bits.fetch(i, default.fetch(i))}.join('-')

    "#{full_date}T00:00:00Z"
  end


  # Round a date up, doing the right thing for shorter months, leap years, etc.
  def self.date_pad_end(s)
    default = [9999, 12, -1]
    bits = s.split('-').map {|s| s =~ /\A\d+\z/ ? s.to_i : nil}
    bits = 3.times.map {|i| bits[i] || default[i]}

    "%sT23:59:59Z" % [Date.new(*bits).iso8601]
  end


  # Either of these parameters might be nil or empty
  def self.build_date_filter(start_date, end_date)
    # A record is NOT in range if its start date is after our end date, OR its
    # end date is before our start date.

    clauses = []

    unless end_date.to_s.empty?
      clauses << "start_date:[#{date_pad_end(end_date)} TO *]"
    end

    unless start_date.to_s.empty?
      clauses << "end_date:[* TO #{date_pad_start(start_date)}]"
    end

    if clauses.empty?
      '*:*'
    else
      "NOT (#{clauses.join(' OR ')})"
    end
  end

  def self.build_supplied_filters(filters)
    return '*:*' if filters.empty?

    clauses = []

    filters.each do |field, value|
      clauses << '%s:%s' % [solr_escape(field), solr_escape(value)]
    end

    clauses.join(' AND ')
  end

  VALID_SORTS = {
    'relevance' => 'score desc',
    'title_asc' => 'title_sort asc',
    'title_desc' => 'title_sort desc',
    'agency_asc' => 'agency_sort asc',
    'agency_desc' => 'agency_sort desc',
    'qsaid_asc' => 'qsaid_sort asc',
    'qsaid_desc' => 'qsaid_sort desc',
  }

  def self.parse_sort(sort_spec)
    VALID_SORTS.fetch(sort_spec)
  end

  def self.resolve_agency_names(facets)
    agency_uris = facets.fetch('creating_agency', []).each_slice(2).map(&:first)
    result = {}

    return result if agency_uris.empty?

    # We're assuming that our facet limit is lower than the maximum number of
    # boolean clauses here, which it should be.  If that changes, we'd need to
    # fire more than one search.
    response = solr_handle_search('q' => '*:*',
                       'fq' => 'uri:(%s)' % agency_uris.map {|uri| solr_escape(uri)}.join(" OR "),
                       'fl' => 'uri,title',
                       'rows' => agency_uris.length,)

    response.fetch('response', {}).fetch('docs', []).each do |doc|
      result[doc.fetch('uri')] = doc.fetch('title')
    end

    result
  end

  def self.add_representations_to_results(formatted_results)
    # Pull back the representations that are directly attached to any Archival
    # Objects on this page and include them in the response payload.

    representation_uris = formatted_results.map {|result|
      if result.fetch('primary_type') == 'archival_object'
        result.fetch('all_representations', [])
      else
        []
      end
    }.flatten.uniq

    return if representation_uris.empty?

    representations_by_uri =
      solr_handle_search('q' => '*:*',
                         'fq' => "{!terms f=uri}#{representation_uris.join(',')}",
                         'rows' => representation_uris.length)
        .fetch('response', {})
        .fetch('docs', [])
        .map {|doc| [doc.fetch('uri'), record_hash(doc)]}
        .to_h


    formatted_results.each do |result|
      if result.fetch('all_representations', nil)
        result['representations_json'] = result.fetch('all_representations').map {|uri|
          representations_by_uri.fetch(uri, nil)
        }.compact
      end
    end
  end

  def self.controlled_records(permissions,
                              q_json,
                              filters,
                              sort,
                              start_date, end_date,
                              page, page_size, facet_fields = nil)

    q = AdvancedSearchQuery.parse(q_json)

    results = solr_handle_search('q' => q.empty? ? '*:*' : q.query_string,
                                 'defType' => 'lucene',
                                 'sort' => parse_sort(sort),
                                 'fq' => [build_controlled_records_filter(permissions),
                                          build_date_filter(start_date, end_date),
                                          build_supplied_filters(filters)],
                                 'rows' => page_size + 1,
                                 'start' => (page * page_size),
                                 'facet' => true,
                                 'facet.field' => facet_fields ? facet_fields : ['primary_type', 'series', 'creating_agency', 'rap_access_status', 'format', 'subjects'],
                                 'facet.mincount' => 1,
                                )
    facets = results.fetch('facet_counts', {}).fetch('facet_fields', {})

    formatted_results = results.fetch('response').fetch('docs').map {|result|
      record_hash(result)
    }[0...page_size]

    add_representations_to_results(formatted_results)

    {
      :results => formatted_results,
      :facets => facets,
      :agency_titles_by_ref => resolve_agency_names(facets),
      :has_next_page => results.fetch('response').fetch('docs').length > page_size,
    }
  end

  def self.controlled_records_csv(permissions,
                                  q_json,
                                  filters,
                                  sort,
                                  start_date, end_date)

    (_, aspace_agency_id) = Ctx.get.current_location.agency.fetch('id').split(':')
    current_agency_uri = "/agents/corporate_entities/#{aspace_agency_id}"

    ControlledRecordsReport.new(controlled_records(permissions,
                                                   q_json,
                                                   filters,
                                                   sort,
                                                   start_date,
                                                   end_date,
                                                   0,
                                                   9999999,
                                                   ['creating_agency']),
                                current_agency_uri)
  end

  def self.select_controlled_records(permissions, record_refs)
    results = solr_handle_search('q' => '*:*',
                                 'fq' => ['{!terms f=id}%s' % record_refs.join(','),
                                          build_controlled_records_filter(permissions)],
                                 'rows' => record_refs.size,
                                 'fl' => 'id',
                                 'start' => 0)

    results.fetch('response').fetch('docs').map {|result|
      result.fetch('id')
    }
  end

  def self.get_records(permissions, record_refs, agency_ref = nil)
    results = solr_handle_search('q' => '*:*',
                                 'fq' => ['{!terms f=id}%s' % record_refs.join(','),
                                          build_controlled_records_filter(permissions, agency_ref)],
                                 'rows' => record_refs.size,
                                 'start' => 0)

    results.fetch('response').fetch('docs').map {|result|
      record_hash(result, agency_ref)
    }
  end

  def self.get_record(record_ref, permissions)
    solr_handle_search(q: "id:#{solr_escape(record_ref)}", fq: build_controlled_records_filter(permissions))
      .fetch('response')
      .fetch('docs')
      .map do |result|
      return record_hash(result)
    end
  end

  def self.uris_for(record_refs)
    result = {}

    return result if record_refs.empty?

    response = solr_handle_search('q' => '*:*',
                                  'fq' => 'id:(%s)' % record_refs.map {|record_ref| solr_escape(record_ref)}.join(" OR "),
                                  'fl' => 'id,uri',
                                  'rows' => record_refs.length,)

    response.fetch('response', {}).fetch('docs', []).each do |doc|
      result[doc.fetch('id')] = doc.fetch('uri')
    end

    result
  end

  # If the user is choosing their items from the search results with no funny
  # business, this should never happen.
  #
  # Just here to catch people monkeying with their requests.
  #
  def self.verify_item_access!(items)
    controlled = select_controlled_records(Ctx.get.permissions, items.map {|item| item.fetch('record_ref')})

    items.each do |item|
      unless controlled.include?(item.fetch('record_ref'))
        Ctx.log_bad_access("verify_item_access!")
        $LOG.error("Requested item '%s' does not appear to be available to current agency" % item.fetch('record_ref'))
        raise StaleRecordException.new
      end
    end
  end
end
