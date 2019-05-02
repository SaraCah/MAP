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

    transfer_identifier = db[:transfer_identifier].insert(transfer_proposal_id: transfer_proposal_id)

    transfer.fetch('files', []).each do |file|
      db[:transfer_file].insert(transfer_id: transfer_identifier,
                                filename: file.fetch('filename'),
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

end