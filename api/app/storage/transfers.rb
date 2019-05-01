class Transfers < BaseStorage

  def self.proposals(page, page_size)
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

  def self.create_proposal_from_dto(transfer, csv_upload)
    raise "FIXME admin user" if Ctx.get.permissions.is_admin?

    db[:transfer].insert(title: transfer.fetch('title'),
                         status: 'ACTIVE',
                         csv: csv_upload.tmp_file.read,
                         csv_filename: transfer.fetch('csv_filename'),
                         agency_id: Ctx.get.current_location.agency_id,
                         agency_location_id: Ctx.get.current_location.id,
                         created_by: Ctx.username,
                         create_time: java.lang.System.currentTimeMillis)
  end

end