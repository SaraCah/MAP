require 'csv'

class TransferReport

  def initialize(transfer_id)
    @transfer_id = transfer_id
    @transfer = Transfers.transfer_dto_for(transfer_id)
    @current_location = Ctx.get.current_location.name
  end

  def archival_objects_dataset(aspacedb)
    aspacedb[:archival_object]
      .filter(transfer_id: @transfer_id)
      .order(Sequel.asc(:id))
      .select(
        :id,
        :qsa_id,
        :agency_assigned_id,
        :title)
  end

  def physical_representations_dataset(aspacedb)
    aspacedb[:physical_representation]
      .join(:representation_container_rlshp, Sequel[:representation_container_rlshp][:physical_representation_id] => Sequel[:physical_representation][:id])
      .join(:top_container, Sequel[:top_container][:id] => Sequel[:representation_container_rlshp][:top_container_id])
      .filter(transfer_id: @transfer_id)
      .order(Sequel.asc(Sequel[:physical_representation][:id]))
      .select(
        Sequel[:physical_representation][:id],
        Sequel[:physical_representation][:qsa_id],
        Sequel[:physical_representation][:agency_assigned_id],
        Sequel[:physical_representation][:title],
        Sequel[:top_container][:indicator])
  end

  def digital_representations_dataset(aspacedb)
    aspacedb[:digital_representation]
        .filter(transfer_id: @transfer_id)
        .order(Sequel.asc(:id))
        .select(
            :id,
            :qsa_id,
            :agency_assigned_id,
            :title)
  end

  def each
    yield CSV.generate_line([
                              'Transfer ID',
                              'Agency Location',
                              'Created By',
                              'Transfer Title',
                              'Agency Control number',
                              'Title',
                              'QSA ITM',
                              'QSA PR',
                              'QSA DR',
                              'QSA Box',
                              'Status',
                              'Transfer Received Date',
                            ])

    AspaceDB.open do |aspacedb|
      archival_objects_dataset(aspacedb).map do |row|
        yield CSV.generate_line([
                                  "T#{@transfer_id}",
                                  @current_location,
                                  @transfer.fetch('lodged_by', nil),
                                  @transfer.fetch('title', nil),
                                  row[:agency_assigned_id],
                                  row[:title],
                                  'ITM%d' % [row[:qsa_id]],
                                  nil,
                                  nil,
                                  nil,
                                  @transfer.fetch('status'),
                                  @transfer.fetch('date_received', nil),
                                ])
      end

      physical_representations_dataset(aspacedb).map do |row|
        yield CSV.generate_line([
                                  "T#{@transfer_id}",
                                  @current_location,
                                  @transfer.fetch('lodged_by', nil),
                                  @transfer.fetch('title', nil),
                                  row[:agency_assigned_id],
                                  row[:title],
                                  nil,
                                  'PR%d' % [row[:qsa_id]],
                                  nil,
                                  row[:indicator],
                                  @transfer.fetch('status'),
                                  @transfer.fetch('date_received', nil),
                                ])
      end

      digital_representations_dataset(aspacedb).map do |row|
        yield CSV.generate_line([
                                  "T#{@transfer_id}",
                                  @current_location,
                                  @transfer.fetch('lodged_by', nil),
                                  @transfer.fetch('title', nil),
                                  row[:agency_assigned_id],
                                  row[:title],
                                  nil,
                                  nil,
                                  'DR%d' % [row[:qsa_id]],
                                  nil,
                                  @transfer.fetch('status'),
                                  @transfer.fetch('date_received', nil),
                                ])
      end
    end
  end
end
