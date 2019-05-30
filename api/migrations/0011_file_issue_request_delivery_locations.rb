Sequel.migration do
  up do

    [:file_issue_request, :file_issue].each do |table|

      alter_table(table) do
        add_column(:delivery_location, String, null: true)
      end

      self[table]
        .filter(deliver_to_reading_room: 1)
        .update(delivery_location: 'READING_ROOM')

      self[table]
        .filter(deliver_to_reading_room: 0)
        .update(delivery_location: 'AGENCY_LOCATION')

      alter_table(table) do
        drop_column(:deliver_to_reading_room)
        set_column_not_null(:delivery_location)
      end

    end
  end

end
