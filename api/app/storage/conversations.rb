class Conversations < BaseStorage

  RECORD_TYPE_TO_COLUMN = {
    :transfer => :handle_id,
  }

  def self.messages_for(handle_id)
    db[:conversation]
      .filter(:handle_id => handle_id)
      .order(:id)
      .map do |row|
      ConversationMessage.from_row(row)
    end
  end

  def self.create(handle_id, message)
    db[:conversation]
      .insert(handle_id: handle_id,
              message: message,
              created_by: Ctx.username,
              create_time: java.lang.System.currentTimeMillis)
  end

  NOTIFICATION_WINDOW = 7 # days
  def self.get_notifications(can_manage_file_issues, can_manage_transfers)
    notifications = []

    [[:transfer_proposal, :transfer_proposal_id, "P%s"],
     [:transfer, :transfer_id, "T%s"],
     [:file_issue_request, :file_issue_request_id, "R%s"],
     [:file_issue, :file_issue_id, "FI%s%s"]].each do |record_type, column, identifier_format|
      next if record_type.to_s.start_with?('file_issue') && !can_manage_file_issues
      next if record_type.to_s.start_with?('transfer') && !can_manage_transfers

      dataset = db[:conversation]
        .join(:handle, Sequel[:conversation][:handle_id] => Sequel[:handle][:id])
        .join(record_type, Sequel[record_type][:id] => Sequel[:handle][column])
        .filter(Sequel[record_type][:agency_id] => Ctx.get.current_location.agency_id)
        .filter(Sequel[record_type][:agency_location_id] => Ctx.get.current_location.id)
        .filter(Sequel[:conversation][:create_time] > (Date.today - NOTIFICATION_WINDOW).to_time.to_i * 1000)
        .filter(Sequel.~(Sequel[:conversation][:created_by] => Ctx.username))
        .select(Sequel[record_type][:id],
                Sequel[:conversation][:message],
                Sequel[:conversation][:created_by],
                Sequel[:conversation][:create_time])

      if record_type == :file_issue
       dataset = dataset.select_append(Sequel[:file_issue][:issue_type])
      end

      dataset
        .each do |row|
          snippet = if row[:message].length > 100
                      row[:message] + '...'
                    else
                      row[:message]
                    end

          identifier = if record_type == :file_issue
                         identifier_format % [row[:issue_type][0], row[:id]]
                       else
                         identifier_format % [row[:id]]
                       end


          notifications << Notification.new(record_type.to_s, 
                                            row[:id],
                                            identifier,
                                            "New comment from #{row[:created_by]}: #{snippet}",
                                            'info',
                                            row[:create_time])
      end
    end

    notifications
  end

end
