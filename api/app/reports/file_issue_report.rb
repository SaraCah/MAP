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


  # FIXME: ignore drafts
  # FIXME: check that they still have access to the representation...

  # FIXME: resolve rep title, agency assigned id
  # FIXME: Date restrictions
  def each
    yield CSV.generate_line(["ID", "Representation Title", "Control Number", "QSA Identifier", "Loan Expiry", "Returned", "Overdue?", "Created By", "Location"])

    DB.open do |mapdb|
      mapdb[:file_issue_request]
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

          yield CSV.generate_line([
                                    "FIR%d" % [row[:id]],
                                    row[:title],
                                    row[:agency_assigned_id],
                                    row[:qsa_id_prefixed],
                                    nil,
                                    nil,
                                    nil,
                                    row[:lodged_by],
                                    nil,
                                  ])
        end
      end
    end
  end
end
