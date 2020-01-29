class Representations
  def self.for(refs)
    # Filter refs to those that this user should be allowed to see.
    refs = Search.select_controlled_records(Ctx.get.permissions, refs)

    results = {}
    parsed_refs = parse_refs(refs)

    AspaceDB.open do |aspace_db|
      parsed_refs.values.group_by {|data| data.fetch(:type)}.each do |jsonmodel_type, grouped_refs|
        ids = grouped_refs.collect{|u| u.fetch(:id)}
        dataset = aspace_db[jsonmodel_type]
          .join(:archival_object, Sequel[:archival_object][:id] => Sequel[jsonmodel_type][:archival_object_id])
          .join(:resource, Sequel[:resource][:id] => Sequel[:archival_object][:root_record_id])
          .left_join(Sequel.as(:enumeration, :intended_use_enum), Sequel[:intended_use_enum][:name] => 'runcorn_intended_use')
          .left_join(Sequel.as(:enumeration_value, :intended_use_enum_value),
                    Sequel.&(Sequel[:intended_use_enum][:id] => Sequel[:intended_use_enum_value][:enumeration_id],
                             Sequel[:intended_use_enum_value][:id] => Sequel[jsonmodel_type][:intended_use_id]))
          .left_join(Sequel.as(:enumeration, :file_issue_allowed_enum), Sequel[:file_issue_allowed_enum][:name] => 'runcorn_file_issue_allowed')
          .left_join(Sequel.as(:enumeration_value, :file_issue_allowed_enum_value),
                     Sequel.&(Sequel[:file_issue_allowed_enum][:id] => Sequel[:file_issue_allowed_enum_value][:enumeration_id],
                              Sequel[:file_issue_allowed_enum_value][:id] => Sequel[jsonmodel_type][:file_issue_allowed_id]))
          .select_all(Sequel[jsonmodel_type])
          .select_append(Sequel.as(Sequel[:archival_object][:qsa_id], :archival_object_qsa_id),
                         Sequel.as(Sequel[:archival_object][:id], :archival_object_id),
                         Sequel.as(Sequel[:resource][:qsa_id], :resource_qsa_id),
                         Sequel.as(Sequel[:intended_use_enum_value][:value], :intended_use_enum_value),
                         Sequel.as(Sequel[:file_issue_allowed_enum_value][:value], :file_issue_allowed_enum_value))

        if jsonmodel_type === :physical_representation
          dataset = dataset
                     .left_join(Sequel.as(:enumeration, :format_enum), Sequel[:format_enum][:name] => 'runcorn_format')
                     .left_join(Sequel.as(:enumeration_value, :format_enum_value),
                                Sequel.&(Sequel[:format_enum][:id] => Sequel[:format_enum_value][:enumeration_id],
                                         Sequel[:format_enum_value][:id] => Sequel[jsonmodel_type][:format_id]))
                      .select_append(Sequel.as(Sequel[:format_enum_value][:value], :format_enum_value))
        end
        if jsonmodel_type === :digital_representation
          dataset = dataset
                      .left_join(Sequel.as(:enumeration, :file_type_enum), Sequel[:file_type_enum][:name] => 'runcorn_digital_file_type')
                      .left_join(Sequel.as(:enumeration_value, :file_type_enum_value),
                                 Sequel.&(Sequel[:file_type_enum][:id] => Sequel[:file_type_enum_value][:enumeration_id],
                                          Sequel[:file_type_enum_value][:id] => Sequel[jsonmodel_type][:file_type_id]))
                      .select_append(Sequel.as(Sequel[:file_type_enum_value][:value], :format_enum_value))
        end

        archival_object_to_representations = {}

        dataset
          .filter(Sequel[jsonmodel_type][:id] => ids).map do |row|
            results[row[:id]] = Representation.new(parsed_refs.fetch(row[:id]).fetch(:ref),   # ref
                                                   row[:resource_qsa_id],                     # series_id
                                                   row[:archival_object_qsa_id],              # record_id
                                                   row[:title],                               # title
                                                   nil,                                       # start_date (calculated below)
                                                   nil,                                       # end_date (calculated below)
                                                   row[:qsa_id],                              # representation_id
                                                   row[:agency_assigned_id],                  # agency_assigned_id
                                                   nil,                                       # previous_system_id (calculated below)
                                                   row[:format_enum_value],                   # format
                                                   row[:file_issue_allowed_enum_value],       # file_issue_allowed
                                                   row[:intended_use_enum_value],             # intended_use
                                                   row[:other_restrictions_notes],            # other_restrictions
                                                   row[:processing_handling_notes])           # processing_handling_notes

            archival_object_to_representations[row[:archival_object_id]] ||= []
            archival_object_to_representations[row[:archival_object_id]] << results[row[:id]]
        end

        # find any existence dates for the items linked to the representations
        existence_label_id = aspace_db[:enumeration_value]
                              .filter(enumeration_id: aspace_db[:enumeration].filter(name: 'date_label').select(:id),
                                      value: 'existence')
                              .select(:id)

        aspace_db[:date]
          .filter(archival_object_id: archival_object_to_representations.keys,
                  label_id: existence_label_id)
          .map do |row|
          archival_object_to_representations.fetch(row[:archival_object_id]).each do |representation|
            representation.start_date = row[:begin]
            representation.end_date = row[:end]
          end
        end

        foreign_key_column = "#{jsonmodel_type}_id".intern
        aspace_db[:external_id]
          .filter(foreign_key_column => results.keys)
          .map do |row|
          results.fetch(row[foreign_key_column]).previous_system_id = row[:external_id] 
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
