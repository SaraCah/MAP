class Representations
  def self.for(uris)
    # FIXME need to filter those user cannot see (as per current agency context)
    results = {}
    parsed_uris = parse_uris(uris)

    AspaceDB.open do |aspace_db|
      parsed_uris.values.group_by {|data| data.fetch(:jsonmodel_type)}.each do |jsonmodel_type, grouped_uris|
        ids = grouped_uris.collect{|u| u.fetch(:id)}
        aspace_db[jsonmodel_type]
          .join(:archival_object, Sequel[:archival_object][:id] => Sequel[jsonmodel_type][:archival_object_id])
          .join(:resource, Sequel[:resource][:id] => Sequel[:archival_object][:root_record_id])
          .select_all(Sequel[jsonmodel_type])
          .select_append(Sequel.as(Sequel[:archival_object][:qsa_id], :archival_object_id),
                         Sequel.as(Sequel[:resource][:qsa_id], :resource_id))
          .filter(Sequel[jsonmodel_type][:id] => ids).map do |row|
          results[row[:id]] = Representation.new(parsed_uris.fetch(row[:id]).fetch(:uri), # uri
                                                 row[:resource_id],           # series_id
                                                 row[:archival_object_id],    # record_id
                                                 row[:title],                 # title
                                                 nil,                         # start_datae
                                                 nil,                         # end_date
                                                 row[:qsa_id],                # representation_id
                                                 nil,                         # agency_assigned_id
                                                 nil,                         # previous_system_id
                                                 nil,                         # format
                                                 nil,                         # file_issue_allowed
                                                 nil,                         # intended_use
                                                 nil,                         # other_restrictions
                                                 nil)                         # processing_notes
        end
      end
    end

    results.values
  end

  def self.parse_uris(uris)
    result = {}

    Array(uris).each do |uri|
      parsed = parse_uri(uri)
      result[parsed.fetch(:id)] = parsed 
    end

    result
  end

  def self.parse_uri(uri)
    if uri =~ /\/repositories\/([0-9]+)\/(digital_representation|physical_representation)s\/([0-9]+)/
      {
        id: $3.to_i,
        jsonmodel_type: $2.intern,
        repo_id: $1.to_i,
        uri: uri,
      }
    else
      raise "Not a representation uri: #{uri}"
    end
  end
end