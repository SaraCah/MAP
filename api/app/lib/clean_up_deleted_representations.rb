require 'set'

class CleanUpdeletedRepresentations
  def self.do_it
    p "***** CleanUpdeletedRepresentations *****"

    digital_representation_ids_to_check = Set.new
    physical_representation_ids_to_check = Set.new

    DB.open do |map_db|
      map_db[:file_issue_item]
        .filter(:aspace_record_type => ['digital_representation', 'physical_representation'])
        .each do |row|
        if row[:aspace_record_type] == 'digital_representation'
          digital_representation_ids_to_check << row[:aspace_record_id].to_i
        end
        if row[:aspace_record_type] == 'physical_representation'
          physical_representation_ids_to_check << row[:aspace_record_id].to_i
        end
      end

      map_db[:file_issue_request_item]
        .filter(:aspace_record_type => ['digital_representation', 'physical_representation'])
        .each do |row|
        if row[:aspace_record_type] == 'digital_representation'
          digital_representation_ids_to_check << row[:aspace_record_id].to_i
        end
        if row[:aspace_record_type] == 'physical_representation'
          physical_representation_ids_to_check << row[:aspace_record_id].to_i
        end
      end
    end

    p "CHECKING digital representations #{digital_representation_ids_to_check}"
    p "CHECKING physical representations #{physical_representation_ids_to_check}"

    digital_representation_ids_no_longer_around = []
    physical_representation_ids_no_longer_around = []

    AspaceDB.open do |aspace_db|
      digital_representation_ids_no_longer_around = digital_representation_ids_to_check.to_a - aspace_db[:digital_representation]
                                                                                                .filter(:id => digital_representation_ids_to_check.to_a)
                                                                                                .select(:id)
                                                                                                .map{|row| row[:id]}

      physical_representation_ids_no_longer_around = physical_representation_ids_to_check.to_a - aspace_db[:physical_representation]
                                                                                                  .filter(:id => physical_representation_ids_to_check.to_a)
                                                                                                  .select(:id)
                                                                                                  .map{|row| row[:id]}
    end

    DB.open do |map_db|
      p "DELETING links to digital representations: #{digital_representation_ids_no_longer_around}"
      p "DELETING links to physical representations: #{physical_representation_ids_no_longer_around}"

      map_db[:file_issue_item]
        .filter(:aspace_record_type => 'digital_representation')
        .filter(:aspace_record_id => digital_representation_ids_no_longer_around)
        .delete

      map_db[:file_issue_request_item]
        .filter(:aspace_record_type => 'digital_representation')
        .filter(:aspace_record_id => digital_representation_ids_no_longer_around)
        .delete

      map_db[:file_issue_item]
        .filter(:aspace_record_type => 'physical_representation')
        .filter(:aspace_record_id => physical_representation_ids_no_longer_around)
        .delete

      map_db[:file_issue_request_item]
        .filter(:aspace_record_type => 'physical_representation')
        .filter(:aspace_record_id => physical_representation_ids_no_longer_around)
        .delete
    end
  end
end