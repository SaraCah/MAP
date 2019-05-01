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
  end

end