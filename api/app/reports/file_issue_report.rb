require 'csv'

class FileIssueReport

  def initialize(start_date, end_date)
    @start_date = start_date
    @end_date = end_date

    @current_location = Ctx.get.current_location

    user_agency_locations = Locations.locations_for_user.select {|location|
      location[:agency_id] == @current_location.agency_id
    }

    is_top_level_selected = !!Ctx.db[:agency_location][id: @current_location.id, top_level_location: 1]

    @user_permissions = Ctx.get.permissions

    @report_locations =
      if is_top_level_selected
        # Report on all locations they have access to
        user_agency_locations.select {|location|
          Ctx.get.permissions.can_manage_file_issues?(location.fetch(:agency_id), location.fetch(:id))
        }
      elsif Ctx.get.permissions.can_manage_file_issues?(@current_location.agency_id, @current_location.id)
        # Just report on the current location
        user_agency_locations.select {|location|
          location.fetch(:id) == @current_location.id
        }
      else
        # No access to the current location
        []
      end
  end

  def resolve_rows(rows)
    record_ids = rows.map {|row|
      solr_id = "%s:%s" % [row.fetch(:aspace_record_type), row.fetch(:aspace_record_id)]
    }

    resolved = Search.get_records(@user_permissions, record_ids, @current_location.agency.fetch('id'))

    resolved
  end

  def file_issue_requests(mapdb)
    base_ds = mapdb[:file_issue_request].filter(draft: 0)

    if @start_date
      from_time = @start_date.to_time.to_i * 1000
      base_ds = base_ds.where { Sequel.qualify(:file_issue_request, :create_time) >= from_time }
    end

    if @end_date
      to_time = @end_date.to_time.to_i * 1000
      base_ds = base_ds.where { Sequel.qualify(:file_issue_request, :create_time) <= to_time }
    end

    base_ds
      .filter(Sequel[:file_issue_request][:agency_id] => @current_location.agency_id)
      .filter(Sequel[:file_issue_request][:agency_location_id] => @report_locations.map {|l| l.fetch(:id)})
      .join(:file_issue_request_item, Sequel[:file_issue_request][:id] => Sequel[:file_issue_request_item][:file_issue_request_id])
      .select(
        Sequel[:file_issue_request][:id],
        Sequel[:file_issue_request_item][:aspace_record_type],
        Sequel[:file_issue_request_item][:aspace_record_id],
        Sequel[:file_issue_request][:lodged_by],
        Sequel[:file_issue_request][:delivery_location])
      .each_page(500) do |page|
      rows = page.all

      resolved_records = resolve_rows(rows).map {|resolved|
        [resolved.fetch('id'), resolved]
      }.to_h

      rows.each do |row|
        solr_id = "%s:%s" % [row.fetch(:aspace_record_type), row.fetch(:aspace_record_id)]

        resolved = resolved_records.fetch(solr_id, nil)

        if resolved
          row[:title] = resolved.fetch('title')
          row[:agency_assigned_id] = resolved.fetch('agency_assigned_id', nil)
          row[:qsa_id_prefixed] = resolved.fetch('qsa_id_prefixed', nil)
        else
          row[:title] = 'You no longer have access to this record.  Please contact QSA for more information.'
        end

        yield row
      end
    end
  end

  def calculate_overdue(row)
    return false if row[:not_returned] == 1
    return false if row[:expiry_date].nil?
    return false unless row[:returned_date].nil?

    row[:expiry_date] < Date.today
  end

  def file_issues(mapdb)
    base_ds = mapdb[:file_issue]

    if @start_date
      from_time = @start_date.to_time.to_i * 1000
      base_ds = base_ds.where { Sequel.qualify(:file_issue, :create_time) >= from_time }
    end

    if @end_date
      to_time = @end_date.to_time.to_i * 1000
      base_ds = base_ds.where { Sequel.qualify(:file_issue, :create_time) <= to_time }
    end

    base_ds
      .filter(Sequel[:file_issue][:agency_id] => @current_location.agency_id)
      .filter(Sequel[:file_issue][:agency_location_id] => @report_locations.map {|l| l.fetch(:id)})
      .join(:file_issue_item, Sequel[:file_issue][:id] => Sequel[:file_issue_item][:file_issue_id])
      .select(
        Sequel[:file_issue][:id],
        Sequel[:file_issue][:issue_type],
        Sequel[:file_issue_item][:aspace_record_type],
        Sequel[:file_issue_item][:aspace_record_id],
        Sequel[:file_issue][:lodged_by],
        Sequel[:file_issue][:delivery_location],
        Sequel[:file_issue_item][:expiry_date],
        Sequel[:file_issue_item][:returned_date],
        Sequel[:file_issue_item][:not_returned])
      .each_page(500) do |page|
      rows = page.all

      resolved_records = resolve_rows(rows).map {|resolved|
        [resolved.fetch('id'), resolved]
      }.to_h

      rows.each do |row|
        solr_id = "%s:%s" % [row.fetch(:aspace_record_type), row.fetch(:aspace_record_id)]

        resolved = resolved_records.fetch(solr_id, nil)

        if resolved
          row[:title] = resolved.fetch('title')
          row[:agency_assigned_id] = resolved.fetch('agency_assigned_id', nil)
          row[:qsa_id_prefixed] = resolved.fetch('qsa_id_prefixed', nil)
        else
          row[:title] = 'You no longer have access to this record.  Please contact QSA for more information.'
        end

        row[:overdue] = calculate_overdue(row)

        yield row
      end
    end
  end

  def each
    yield CSV.generate_line(["ID", "Representation Title", "Control Number", "QSA Identifier", "Loan Expiry", "Returned", "Overdue?", "Created By", "Location"])

    DB.open do |mapdb|
      file_issue_requests(mapdb) do |row|
        yield CSV.generate_line([
                                  "FIR%d" % [row[:id]],
                                  row[:title],
                                  row[:agency_assigned_id],
                                  row[:qsa_id_prefixed],
                                  nil,
                                  nil,
                                  nil,
                                  row[:lodged_by],
                                  row[:delivery_location],
                                ])
      end

      file_issues(mapdb) do |row|
        yield CSV.generate_line([
                                  "FI%s%d" % [row[:issue_type][0], row[:id]],
                                  row[:title],
                                  row[:agency_assigned_id],
                                  row[:qsa_id_prefixed],
                                  row[:expiry_date],
                                  row[:returned_date],
                                  row[:overdue],
                                  row[:lodged_by],
                                  row[:delivery_location],
                                ])
      end
    end
  end
end
