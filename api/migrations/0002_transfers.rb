Sequel.migration do
  up do

    create_table(:transfer_proposal) do
      primary_key :id

      foreign_key :agency_id, :agency, null: false
      foreign_key :agency_location_id, :agency_location, null: false

      String :title, null: false
      String :estimated_quantity

      String :status, null: false

      String :created_by, null: false
      Bignum :create_time, null: false

      # This here for ArchivesSpace ASModel compatibility
      DateTime :system_mtime, :null => false, :index => true
    end

    run 'CREATE TRIGGER `transfer_proposal_insert_set_system_mtime` before insert on transfer_proposal for each row set new.system_mtime = UTC_TIMESTAMP()'
    run 'CREATE TRIGGER `transfer_proposal_update_set_system_mtime` before update on transfer_proposal for each row set new.system_mtime = UTC_TIMESTAMP()'

    create_table(:transfer) do
      primary_key :id

      foreign_key :agency_id, :agency, null: false
      foreign_key :agency_location_id, :agency_location, null: false

      String :title, null: false

      String :checklist_status, null: false
      String :status, null: false

      Bignum :date_scheduled
      Bignum :date_received
      Integer :quantity_received

      String :created_by, null: false
      Bignum :create_time, null: false
    end

    create_table(:handle) do
      primary_key :id

      foreign_key :transfer_proposal_id, :transfer_proposal
      foreign_key :transfer_id, :transfer
    end

    create_table(:transfer_proposal_series) do
      primary_key :id

      foreign_key :transfer_proposal_id, :transfer_proposal, null: false

      # FIXME sizes?
      String :series_title
      String :disposal_class
      String :date_range
      String :accrual_details, text: true
      String :creating_agency
      String :mandate
      String :function
      String :system_of_arrangement
      Integer :composition_digital, null: false, default: 0
      Integer :composition_hybrid, null: false, default: 0
      Integer :composition_physical, null: false, default: 0
    end

    create_table(:conversation) do
      primary_key :id

      foreign_key :handle_id, :handle, null: false

      String :message, text: true, null: false

      String :created_by, null: false
      Bignum :create_time, null: false
    end

    create_table(:transfer_file) do
      primary_key :id

      foreign_key :handle_id, :handle, null: false

      String :key, null: false
      String :filename, null: false
      String :role, null: false

      String :mime_type, null: false

      String :created_by, null: false
      Bignum :create_time, null: false
    end

    create_table(:file) do
      primary_key :id

      String :key, null: false
      File :blob, :size => :long, null: false
    end
  end
end
