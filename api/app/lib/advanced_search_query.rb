require 'json'

class AdvancedSearchQuery
  attr_reader :query_string

  # These fields will be rewritten into queries that target multiple underlying Solr fields with specified weights
  EXPANDED_FIELDS = {
    'keywords' => [
      {'field' => 'keywords', 'weight' => 2},
      {'field' => 'keywords_stemmed', 'weight' => 1},
    ],
    'qsa_id' => [
      {'field' => 'qsa_id_prefixed', 'weight' => 1},
      {'field' => 'qsa_id', 'weight' => 1},
    ],
    'agency_id' => [
      {'field' => 'agency_assigned_id', 'weight' => 1},
    ],
    'title' => [
      {'field' => 'title_text', 'weight' => 2},
      {'field' => 'title_text_stemmed', 'weight' => 1},
    ],
    'transfer_id' => [
      {'field' => 'transfer_id', 'weight' => 1},
    ],
    'series_number' => [
      {'field' => 'series_qsa_id_prefixed', 'weight' => 2},
      {'field' => 'series_qsa_id', 'weight' => 1},
    ],
    'box_number' => [
      {'field' => 'top_container', 'weight' => 1},
    ],
    'previous_id' => [
      {'field' => 'previous_system_identifiers', 'weight' => 1},
    ],
  }


  # space and double quote are also meaningful, but let those through for now
  SOLR_CHARS = '+-&|!(){}[]^~*?:\\/'

  def self.parse(json)
    new(JSON.parse(json))
  end

  def initialize(query)
    @query_string = parse_query(query)
  end

  def empty?
    @query_string.empty?
  end

  private

  def solr_escape(s)
    pattern = Regexp.quote(SOLR_CHARS)
    s.gsub(/([#{pattern}])/, '\\\\\1')
  end

  def parse_query(clauses)
    clauses = Array(clauses).reject {|clause| clause['query'].to_s.empty?}

    if clauses.empty?
      # No query/queries given
      return ''
    end

    clauses = clauses.each_with_index.map {|clause, idx|
      operator = clause.fetch('op')
      negated = false

      if operator == 'NOT'
        # NOT isn't really a boolean operator--really means AND NOT.  We're not
        # judging.
        operator = 'AND'
        negated = true
      end

      target_field = clause.fetch('field')
      [
        # combining operator if we're not on the first clause
        "%s %s(%s)" % [
          (idx == 0) ? '' : operator,
          negated ? '-' : '',
          EXPANDED_FIELDS.fetch(target_field, [{'field' => target_field, 'weight' => 1}]).map {|fieldspec|
            "%s:(%s)^%d" % [
              fieldspec.fetch('field'),
              solr_escape(clause.fetch('query')),
              fieldspec.fetch('weight'),
            ]
          }.join(' OR ')
        ]
      ]
    }.flatten.reject(&:empty?)

    clauses.drop(1).reduce(clauses.first) {|query, clause|
      "(%s %s)" % [query, clause]
    }
  end

end
