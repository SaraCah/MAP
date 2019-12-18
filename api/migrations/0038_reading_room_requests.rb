Sequel.migration do
  up do
    create_table(:reading_room_request) do
      primary_key :id

      foreign_key :agency_id, :agency, null: false
      foreign_key :agency_location_id, :agency_location, null: false

      String :item_id, null: false
      String :item_uri, null: false

      String :status, null: false
      Bignum :date_required
      String :time_required

      String :created_by, null: false
      String :modified_by, null: false
      Bignum :create_time, null: false
      Bignum :modified_time, null: false

      # This here for ArchivesSpace ASModel compatibility
      Integer :lock_version, :default => 1, :null => false
      DateTime :system_mtime, :index => true, :null => false
    end

    alter_table(:reading_room_request) do
      add_index([:item_id], name: "rr_req_item_id_idx")
    end

    alter_table(:handle) do
      add_foreign_key(:reading_room_request_id, :reading_room_request, null: true)
    end

  end
end
