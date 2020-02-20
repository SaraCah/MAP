class Transfers < BaseStorage

  PROPOSAL_SORT_OPTIONS = {
    'id_asc' => Sequel.asc(Sequel[:transfer_proposal][:id]),
    'id_desc' => Sequel.desc(Sequel[:transfer_proposal][:id]),
    'title_asc' => Sequel.asc(Sequel.function(:lower, Sequel[:transfer_proposal][:title])),
    'title_desc' => Sequel.desc(Sequel.function(:lower, Sequel[:transfer_proposal][:title])),
    'status_asc' => Sequel.asc(Sequel[:transfer_proposal][:status]),
    'status_desc' => Sequel.desc(Sequel[:transfer_proposal][:status]),
    'created_asc' => Sequel.asc(Sequel[:transfer_proposal][:create_time]),
    'created_desc' => Sequel.desc(Sequel[:transfer_proposal][:create_time]),
  }

  TRANSFER_SORT_OPTIONS = {
    'id_asc' => Sequel.asc(Sequel[:transfer][:id]),
    'id_desc' => Sequel.desc(Sequel[:transfer][:id]),
    'title_asc' => Sequel.asc(Sequel.function(:lower, Sequel[:transfer][:title])),
    'title_desc' => Sequel.desc(Sequel.function(:lower, Sequel[:transfer][:title])),
    'status_asc' => Sequel.asc(Sequel[:transfer][:status]),
    'status_desc' => Sequel.desc(Sequel[:transfer][:status]),
    'created_asc' => Sequel.asc(Sequel[:transfer][:create_time]),
    'created_desc' => Sequel.desc(Sequel[:transfer][:create_time]),
  }


  def self.proposals(page, page_size, status = nil, sort = nil)
    dataset = db[:transfer_proposal]

    unless Ctx.get.permissions.is_admin?
      current_location = Ctx.get.current_location
      dataset = dataset
                  .filter(Sequel[:transfer_proposal][:agency_id] => current_location.agency_id)
                  .filter(Sequel[:transfer_proposal][:agency_location_id] => current_location.id)
    end

    if status && TransferProposal::STATUS_OPTIONS.include?(status)
      dataset = dataset.filter(Sequel[:transfer_proposal][:status] => status)
    end

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

    sort_by = PROPOSAL_SORT_OPTIONS.fetch(sort, PROPOSAL_SORT_OPTIONS.fetch('id_desc'))

    dataset = dataset.order(sort_by)

    PagedResults.new(dataset.map{|row| TransferProposal.from_row(row)},
                     page,
                     max_page)
  end


  def self.create_proposal_from_dto(transfer)
    errors = []

    raise "FIXME admin user" if Ctx.get.permissions.is_admin?

    lodged_by = nil

    if transfer.fetch('status') == TransferProposal::STATUS_ACTIVE
      username = Users.name_for(Ctx.username)
      position = Ctx.get.user_position
      lodged_by = "%s (%s)" % [username, position]
    end

    transfer_proposal_id = db[:transfer_proposal].insert(title: transfer.fetch('title'),
                                                         description: transfer.fetch('description', nil),
                                                         status: transfer.fetch('status'),
                                                         estimated_quantity: transfer.fetch('estimated_quantity', nil),
                                                         agency_id: Ctx.get.current_location.agency_id,
                                                         agency_location_id: Ctx.get.current_location.id,
                                                         lodged_by: lodged_by,
                                                         created_by: Ctx.username,
                                                         create_time: java.lang.System.currentTimeMillis,
                                                         modified_by: Ctx.username,
                                                         modified_time: java.lang.System.currentTimeMillis,
                                                         system_mtime: Time.now)

    handle = db[:handle].insert(transfer_proposal_id: transfer_proposal_id)

    transfer.fetch('files', []).each do |file|
      db[:transfer_file].insert(handle_id: handle,
                                filename: file.fetch('filename'),
                                mime_type: file.fetch('mime_type'),
                                key: file.fetch('key'),
                                role: 'OTHER',
                                created_by: Ctx.username,
                                create_time: java.lang.System.currentTimeMillis)
    end

    transfer.fetch('series', []).each do |series|
      db[:transfer_proposal_series].insert(transfer_proposal_id: transfer_proposal_id,
                                           series_title: series.fetch('series_title', nil),
                                           description: series.fetch('description', nil),
                                           disposal_class: series.fetch('disposal_class', nil),
                                           date_range: series.fetch('date_range', nil),
                                           accrual: series.fetch('accrual', false) ? 1 : 0,
                                           accrual_details: series.fetch('accrual_details', nil),
                                           creating_agency: series.fetch('creating_agency', nil),
                                           mandate: series.fetch('mandate', nil),
                                           function: series.fetch('function', nil),
                                           system_of_arrangement: series.fetch('system_of_arrangement', nil),
                                           composition_digital: series.fetch('composition_digital', false ) ? 1 : 0,
                                           composition_hybrid: series.fetch('composition_hybrid', false ) ? 1 : 0,
                                           composition_physical: series.fetch('composition_physical', false ) ? 1 : 0)
    end

    errors
  end


  def self.update_proposal_from_dto(transfer)
    errors = []

    transfer_proposal_id = transfer.fetch('id')
    handle = db[:handle][transfer_proposal_id: transfer_proposal_id][:id]

    update_data = {
      title: transfer.fetch('title'),
      description: transfer.fetch('description', nil),
      estimated_quantity: transfer.fetch('estimated_quantity', nil),
      status: transfer.fetch('status'),
      lock_version: transfer.fetch('lock_version') + 1,
      modified_by: Ctx.username,
      modified_time: java.lang.System.currentTimeMillis,
      system_mtime: Time.now
    }

    if transfer.fetch('status') == TransferProposal::STATUS_ACTIVE && db[:transfer_proposal][id: transfer_proposal_id][:status] == TransferProposal::STATUS_INACTIVE
      username = Users.name_for(Ctx.username)
      position = Ctx.get.user_position
      update_data[:lodged_by] = "%s (%s)" % [username, position]
    end

    updated = db[:transfer_proposal]
                .filter(id: transfer_proposal_id)
                .filter(lock_version: transfer.fetch('lock_version'))
                .update(update_data)

    raise StaleRecordException.new if updated == 0

    db[:transfer_file]
      .filter(handle_id: handle)
      .delete

    transfer.fetch('files', []).each do |file|
      db[:transfer_file].insert(handle_id: handle,
                                filename: file.fetch('filename'),
                                mime_type: file.fetch('mime_type'),
                                key: file.fetch('key'),
                                role: 'OTHER',
                                created_by: Ctx.username,
                                create_time: java.lang.System.currentTimeMillis)
    end

    db[:transfer_proposal_series]
      .filter(transfer_proposal_id: transfer_proposal_id)
      .delete

    transfer.fetch('series', []).each do |series|
      db[:transfer_proposal_series].insert(transfer_proposal_id: transfer_proposal_id,
                                           series_title: series.fetch('series_title', nil),
                                           description: series.fetch('description', nil),
                                           disposal_class: series.fetch('disposal_class', nil),
                                           date_range: series.fetch('date_range', nil),
                                           accrual: series.fetch('accrual', false) ? 1 : 0,
                                           accrual_details: series.fetch('accrual_details', nil),
                                           creating_agency: series.fetch('creating_agency', nil),
                                           mandate: series.fetch('mandate', nil),
                                           function: series.fetch('function', nil),
                                           system_of_arrangement: series.fetch('system_of_arrangement', nil),
                                           composition_digital: series.fetch('composition_digital', false ) ? 1 : 0,
                                           composition_hybrid: series.fetch('composition_hybrid', false ) ? 1 : 0,
                                           composition_physical: series.fetch('composition_physical', false ) ? 1 : 0)
    end

    errors
  end


  def self.proposal_dto_for(transfer_proposal_id)
    handle = db[:handle][transfer_proposal_id: transfer_proposal_id][:id]
    TransferProposal.from_row(db[:transfer_proposal][id: transfer_proposal_id],
                              handle,
                              db[:transfer_file].filter(handle_id: handle),
                              db[:transfer_proposal_series].filter(transfer_proposal_id: transfer_proposal_id),
                              (transfer_id = db[:transfer].filter(transfer_proposal_id: transfer_proposal_id).get(:id)),
                             )
  end


  def self.cancel_proposal(transfer_proposal_id)
    db[:transfer_proposal]
      .filter(id: transfer_proposal_id)
      .update(status: 'CANCELLED_BY_AGENCY',
              modified_by: Ctx.username,
              modified_time: java.lang.System.currentTimeMillis,
              system_mtime: Time.now)
  end


  def self.delete_proposal(transfer_proposal_id)
    db[:handle]
      .filter(transfer_proposal_id: transfer_proposal_id)
      .delete

    db[:transfer_proposal_series]
      .filter(transfer_proposal_id: transfer_proposal_id)
      .delete

    db[:transfer_proposal]
      .filter(id: transfer_proposal_id)
      .delete
  end


  def self.transfers(page, page_size, status = nil, sort = nil)
    dataset = db[:transfer]

    unless Ctx.get.permissions.is_admin?
      current_location = Ctx.get.current_location
      dataset = dataset
                  .filter(Sequel[:transfer][:agency_id] => current_location.agency_id)
                  .filter(Sequel[:transfer][:agency_location_id] => current_location.id)
    end

    if status && Transfer::STATUS_OPTIONS.include?(status)
      dataset = dataset.filter(Sequel[:transfer][:status] => status)
    end

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

    sort_by = TRANSFER_SORT_OPTIONS.fetch(sort, TRANSFER_SORT_OPTIONS.fetch('id_desc'))

    dataset = dataset.order(sort_by)

    PagedResults.new(dataset.map{|row| Transfer.from_row(row)},
                     page,
                     max_page)
  end


  def self.transfer_dto_for(transfer_id)
    handle = db[:handle][transfer_id: transfer_id][:id]
    Transfer.from_row(db[:transfer][id: transfer_id],
                      handle,
                      db[:transfer_file].filter(handle_id: handle))
  end

  def self.update_transfer_from_dto(transfer)
    errors = []

    original_transfer = transfer_dto_for(transfer.fetch('id'))

    needs_metadata = (original_transfer.fetch('checklist_metadata_received', false) || original_transfer.fetch('checklist_metadata_approved', false))
    has_metadata = transfer.fetch('files', []).any? {|file| file.fetch('role') == 'IMPORT'}

    needs_rap = original_transfer.fetch('checklist_rap_received', false)
    had_rap_before = original_transfer.fetch('files', []).any? {|file| file.fetch('role') == 'RAP'}
    has_rap_now = transfer.fetch('files', []).any? {|file| file.fetch('role') == 'RAP'}

    if needs_metadata && !has_metadata
      errors << "Cannot delete metadata file after it has been approved"
    end

    if needs_rap && had_rap_before && !has_rap_now
      # No removing the RAP that's already been approved
      errors << "Cannot delete RAP file after it has been approved"
    end

    if needs_rap && !had_rap_before && has_rap_now
      # You're adding a RAP to a record that doesn't need one.  If we let this
      # go through with role = RAP, you're not going to be able to remove this
      # file.  Switch it to "other".
      transfer.fetch('files', []).each do |file|
        if file.fetch('role') == 'RAP'
          file['role'] = 'OTHER'
        end
      end
    end

    return errors if !errors.empty?

    transfer_id = transfer.fetch('id')
    handle = db[:handle][transfer_id: transfer_id][:id]

    updated = db[:transfer]
                .filter(id: transfer_id)
                .filter(lock_version: transfer.fetch('lock_version'))
                .update(lock_version: transfer.fetch('lock_version') + 1,
                        modified_by: Ctx.username,
                        modified_time: java.lang.System.currentTimeMillis,
                        system_mtime: Time.now)

    raise StaleRecordException.new if updated == 0

    db[:transfer_file]
      .filter(handle_id: handle)
      .delete

    transfer.fetch('files', []).each do |file|
      db[:transfer_file].insert(handle_id: handle,
                                filename: file.fetch('filename'),
                                mime_type: file.fetch('mime_type'),
                                key: file.fetch('key'),
                                role: file.fetch('role', 'OTHER'),
                                created_by: Ctx.username,
                                create_time: java.lang.System.currentTimeMillis)
    end

    errors
  end


  def self.cancel_transfer(transfer_id)
    db[:transfer]
      .filter(id: transfer_id)
      .update(status: 'TRANSFER_PROCESS_CANCELLED_BY_AGENCY',
              modified_by: Ctx.username,
              modified_time: java.lang.System.currentTimeMillis,
              system_mtime: Time.now)
  end


  def self.get_notifications
    notifications = []

    [[:transfer_proposal, 'Proposal', 'P%s'],
     [:transfer, 'Transfer', 'T%s']].each do |record_type, label, identifier_format|
      # created
      db[record_type]
        .filter(Sequel[record_type][:agency_id] => Ctx.get.current_location.agency_id)
        .filter(Sequel[record_type][:agency_location_id] => Ctx.get.current_location.id)
        .filter(Sequel[record_type][:create_time] > (Date.today - Notifications::NOTIFICATION_WINDOW).to_time.to_i * 1000)
        .select(Sequel[record_type][:id],
                Sequel[record_type][:create_time],
                Sequel[record_type][:created_by])
        .each do |row|
        notifications << Notification.new(record_type,
                                          row[:id],
                                          identifier_format % [row[:id]],
                                          "%s created by %s" % [label, row[:created_by]],
                                          'info',
                                          row[:create_time])
      end

      # modified
      db[record_type]
        .filter(Sequel[record_type][:agency_id] => Ctx.get.current_location.agency_id)
        .filter(Sequel[record_type][:agency_location_id] => Ctx.get.current_location.id)
        .filter(Sequel[record_type][:modified_time] > Sequel[record_type][:create_time])
        .filter(Sequel[record_type][:modified_time] > (Date.today - Notifications::NOTIFICATION_WINDOW).to_time.to_i * 1000)
        .select(Sequel[record_type][:id],
                Sequel[record_type][:modified_time],
                Sequel[record_type][:modified_by])
        .each do |row|
        notifications << Notification.new(record_type,
                                          row[:id],
                                          identifier_format % [row[:id]],
                                          "%s updated by %s" % [label, row[:modified_by]],
                                          'info',
                                          row[:modified_time])
      end
    end

    notifications
  end
end
