class ControlledRecordsReport

  def initialize(search_results, current_agency_uri)
    @results = search_results
    @current_agency_uri = current_agency_uri
  end

  def find_creating_agency(agency_ref)
    @results.dig(:agency_titles_by_ref, agency_ref)
  end

  def each
    yield CSV.generate_line([
                              'Record Type',
                              'Title',
                              'QSA ID',
                              'Agency Control No.',
                              'Previous System ID',
                              'Start Date',
                              'End Date',
                              'Transfer ID',
                              'Container ID',
                              'Series ID',
                              'Series Name',
                              'Access Status',
                              'RAP Years',
                              'RAP Expiry Date',
                              'Metadata Published?',
                              'Creating Agency',
                              'Format',
                              'Subjects',
                              'No of Items',
                              'No of Physical Representations',
                              'No of Digital Representations',
                              'Under Movement?',
                              'ArchivesSearch link'
                            ])

    Array(@results[:results]).each do |record|
      require 'pp'
      pp record

      yield CSV.generate_line([
                               primary_type_for(record),
                               title_for(record),
                               qsa_id_for(record),
                               agency_control_number_for(record),
                               previous_system_identifer_for(record),
                               start_date_for(record),
                               end_date_for(record),
                               transfer_id_for(record),
                               container_id_for(record),
                               series_id_for(record),
                               series_name_for(record),
                               access_status_for(record),
                               rap_years_for(record),
                               rap_expiry_date_for(record),
                               metadata_published_for(record),
                               creating_agency_for(record),
                               format_for(record),
                               subjects_for(record),
                               number_of_items_for(record),
                               number_of_physical_representations_for(record),
                               number_of_digital_representations_for(record),
                               under_movement_for(record),
                               public_link_for(record),
                             ])
    end
  end

  PRIMARY_TYPES = {
    'resource' => 'Series',
    'archival_object' => 'Record',
    'digital_representation' => 'Digital Representation',
    'physical_representation' => 'Physical Representation',
  }

  def primary_type_for(record)
    PRIMARY_TYPES.fetch(record['primary_type'])
  end

  def title_for(record)
    record['base_title'] || record['title']
  end

  def qsa_id_for(record)
    record['qsa_id_prefixed']
  end

  def agency_control_number_for(record)
    record['agency_assigned_id']
  end

  def previous_system_identifer_for(record)
    record['previous_system_identifiers']
  end

  def start_date_for(record)
    record['raw_start_date']
  end

  def end_date_for(record)
    record['raw_end_date']
  end

  def transfer_id_for(record)
    record['transfer_id']
  end

  def container_id_for(record)
    record['top_container']
  end

  def series_id_for(record)
    record['series_qsa_id_prefixed'] || record['series_qsa_id']
  end

  def series_name_for(record)
    record['series']
  end

  def access_status_for(record)
    record['rap_access_status']
  end

  def rap_years_for(record)
    record['rap_years']
  end

  def rap_expiry_date_for(record)
    record['rap_expiry_date']
  end

  def metadata_published_for(record)
    if record.has_key?('rap_open_access_metadata')
      record['rap_open_access_metadata'] ? 'Y' : 'N'
    end
  end

  def creating_agency_for(record)
    if record['creating_agency']
      Array(record['creating_agency']).map{|agency_uri| find_creating_agency(agency_uri)}.compact.join('; ')
    end
  end

  def format_for(record)
    record['format']
  end

  def subjects_for(record)
    if record['subjects']
      Array(record['subjects']).join('; ')
    end
  end

  def number_of_items_for(record)
    record['items_count']
  end

  def number_of_physical_representations_for(record)
    record['physical_representations_count']
  end

  def number_of_digital_representations_for(record)
    record['digital_representations_count']
  end

  def under_movement_for(record)
    if record['responsible_agency']
      record.dig('responsible_agency') == @current_agency_uri ? nil : 'Y'
    end
  end

  def public_link_for(record)
    if record['published']
      url = AppConfig.has_key?(:public_url) ? AppConfig[:public_url] : ''

      if record['primary_type'] == 'resource'
        url += "/series/" + record['qsa_id_prefixed']
      elsif record['primary_type'] == 'archival_object'
        url += "/items/" + record['qsa_id_prefixed']
      elsif record['primary_type'] == 'physical_representation'
        url += "/items/" + record['containing_record_qsa_id_prefixed']
      elsif record['primary_type'] == 'digital_representation'
        url += "/items/" + record['containing_record_qsa_id_prefixed']
      end

      url
    end
  end
end