class Transfers < BaseStorage

  def self.proposals(page, page_size)
    dataset = db[:transfer_proposal]

    unless Ctx.get.permissions.is_admin?
      current_location = Ctx.get.current_location
      dataset = dataset
                  .filter(Sequel[:transfer_proposal][:agency_id] => current_location.agency_id)
                  .filter(Sequel[:transfer_proposal][:agency_location_id] => current_location.id)
    end

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

    PagedResults.new(dataset.map{|row| TransferProposal.from_row(row)},
                     page,
                     max_page)
  end


  def self.create_proposal_from_dto(transfer)
    raise "FIXME admin user" if Ctx.get.permissions.is_admin?

    transfer_proposal_id = db[:transfer_proposal].insert(title: transfer.fetch('title'),
                                                         status: 'ACTIVE',
                                                         estimated_quantity: transfer.fetch('estimated_quantity', nil),
                                                         agency_id: Ctx.get.current_location.agency_id,
                                                         agency_location_id: Ctx.get.current_location.id,
                                                         created_by: Ctx.username,
                                                         create_time: java.lang.System.currentTimeMillis)

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
                                           disposal_class: series.fetch('disposal_class', nil),
                                           date_range: series.fetch('date_range', nil),
                                           accrual_details: series.fetch('accrual_details', nil),
                                           creating_agency: series.fetch('creating_agency', nil),
                                           mandate: series.fetch('mandate', nil),
                                           function: series.fetch('function', nil),
                                           system_of_arrangement: series.fetch('system_of_arrangement', nil),
                                           composition_digital: series.fetch('composition_digital', false ) ? 1 : 0,
                                           composition_hybrid: series.fetch('composition_hybrid', false ) ? 1 : 0,
                                           composition_physical: series.fetch('composition_physical', false ) ? 1 : 0)
    end
  end


  def self.update_proposal_from_dto(transfer)
    # FIXME check permissions

    transfer_proposal_id = transfer.fetch('id')
    handle = db[:handle][transfer_proposal_id: transfer_proposal_id][:id]

    db[:transfer_proposal]
      .filter(id: transfer_proposal_id)
      .update(title: transfer.fetch('title'),
              estimated_quantity: transfer.fetch('estimated_quantity', nil))


    file_keys_to_remove = db[:transfer_file].filter(handle_id: handle).select(:key).all

    db[:transfer_file]
      .filter(handle_id: handle)
      .delete

    db[:file]
      .filter(key: file_keys_to_remove)
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
                                           disposal_class: series.fetch('disposal_class', nil),
                                           date_range: series.fetch('date_range', nil),
                                           accrual_details: series.fetch('accrual_details', nil),
                                           creating_agency: series.fetch('creating_agency', nil),
                                           mandate: series.fetch('mandate', nil),
                                           function: series.fetch('function', nil),
                                           system_of_arrangement: series.fetch('system_of_arrangement', nil),
                                           composition_digital: series.fetch('composition_digital', false ) ? 1 : 0,
                                           composition_hybrid: series.fetch('composition_hybrid', false ) ? 1 : 0,
                                           composition_physical: series.fetch('composition_physical', false ) ? 1 : 0)
    end
  end


  def self.proposal_dto_for(transfer_proposal_id)
    handle = db[:handle][transfer_proposal_id: transfer_proposal_id][:id]
    TransferProposal.from_row(db[:transfer_proposal][id: transfer_proposal_id],
                              handle,
                              db[:transfer_file].filter(handle_id: handle),
                              db[:transfer_proposal_series].filter(transfer_proposal_id: transfer_proposal_id))
  end


  def self.cancel_proposal(transfer_proposal_id)
    db[:transfer_proposal]
      .filter(id: transfer_proposal_id)
      .update(status: 'CANCELLED_BY_AGENCY')
  end


  def self.transfers(page, page_size)
    dataset = db[:transfer]

    unless Ctx.get.permissions.is_admin?
      current_location = Ctx.get.current_location
      dataset = dataset
                  .filter(Sequel[:transfer][:agency_id] => current_location.agency_id)
                  .filter(Sequel[:transfer][:agency_location_id] => current_location.id)
    end

    max_page = (dataset.count / page_size.to_f).ceil

    dataset = dataset.limit(page_size, page * page_size)

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
    # FIXME check permissions

    transfer_id = transfer.fetch('id')
    handle = db[:handle][transfer_id: transfer_id][:id]

    file_keys_to_remove = db[:transfer_file].filter(handle_id: handle).select(:key).all

    db[:transfer_file]
      .filter(handle_id: handle)
      .delete

    db[:file]
      .filter(key: file_keys_to_remove)
      .delete

    transfer.fetch('files', []).each do |file|
      db[:transfer_file].insert(handle_id: handle,
                                filename: file.fetch('filename'),
                                mime_type: file.fetch('mime_type'),
                                key: file.fetch('key'),
                                role: file.fetch('role', 'other'),
                                created_by: Ctx.username,
                                create_time: java.lang.System.currentTimeMillis)
    end
  end
end
