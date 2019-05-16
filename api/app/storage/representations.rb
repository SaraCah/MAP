class Representations
  def self.for(refs)
    # FIXME need to filter those user cannot see (as per current agency context)
    results = {}
    parsed_refs = parse_refs(refs)

    AspaceDB.open do |aspace_db|
      parsed_refs.values.group_by {|data| data.fetch(:type)}.each do |jsonmodel_type, grouped_refs|
        ids = grouped_refs.collect{|u| u.fetch(:id)}
        aspace_db[jsonmodel_type]
          .join(:archival_object, Sequel[:archival_object][:id] => Sequel[jsonmodel_type][:archival_object_id])
          .join(:resource, Sequel[:resource][:id] => Sequel[:archival_object][:root_record_id])
          .select_all(Sequel[jsonmodel_type])
          .select_append(Sequel.as(Sequel[:archival_object][:qsa_id], :archival_object_id),
                         Sequel.as(Sequel[:resource][:qsa_id], :resource_id))
          .filter(Sequel[jsonmodel_type][:id] => ids).map do |row|
          results[row[:id]] = Representation.new(parsed_refs.fetch(row[:id]).fetch(:ref),  # ref
                                                 row[:resource_id],                       # series_id
                                                 row[:archival_object_id],                # record_id
                                                 row[:title],                             # title
                                                 nil,                                     # start_datae
                                                 nil,                                     # end_date
                                                 row[:qsa_id],                            # representation_id
                                                 nil,                                     # agency_assigned_id
                                                 nil,                                     # previous_system_id
                                                 nil,                                     # format
                                                 nil,                                     # file_issue_allowed
                                                 nil,                                     # intended_use
                                                 nil,                                     # other_restrictions
                                                 nil)                                     # processing_notes
        end
      end
    end

    results.values
  end

  def self.parse_refs(refs)
    result = {}

    Array(refs).each do |ref|
      parsed = parse_ref(ref)
      result[parsed.fetch(:id)] = parsed 
    end

    result
  end

  def self.parse_ref(ref)
    if ref =~ /(digital_representation|physical_representation)\:([0-9]+)/
      {
        id: $2.to_i,
        type: $1.intern,
        ref: ref,
      }
    else
      raise "Not a representation ref: #{ref}"
    end
  end
end