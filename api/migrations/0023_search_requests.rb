Sequel.migration do
  up do

    create_table(:search_request) do
      primary_key :id

      foreign_key :agency_id, :agency, null: false
      foreign_key :agency_location_id, :agency_location, null: false

      String :details, text: true, null: false

      String :status
      Integer :draft, null: false, default: 0

      Integer :aspace_quote_id

      String :created_by, null: false
      Bignum :create_time, null: false
      String :modified_by, null: false
      Bignum :modified_time, null: false
      Integer :version, null: false, default: 0

      # This here for ArchivesSpace ASModel compatibility
      Integer :lock_version, :default => 1, :null => false
      DateTime :system_mtime, :index => true, :null => false
    end

    create_table(:search_request_item) do
      primary_key :id

      foreign_key :search_request_id, :search_request, null: false

      String :aspace_record_type, null: false
      Integer :aspace_record_id, null: false
    end

    alter_table(:handle) do
      add_foreign_key(:search_request_id, :search_request, null: true)
    end

  end
end
