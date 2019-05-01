Sequel.migration do
  up do

    create_table(:transfer_proposal) do
      primary_key :id

      foreign_key :agency_id, :agency, null: false
      foreign_key :agency_location_id, :agency_location, null: false

      String :title, null: false

      String :status, null: false

      String :created_by, null: false
      Bignum :create_time, null: false
    end

    create_table(:transfer) do
      primary_key :id

      foreign_key :agency_id, :agency, null: false
      foreign_key :agency_location_id, :agency_location, null: false

      String :title, null: false

      String :checklist_status, null: false
      String :status, null: false

      String :created_by, null: false
      Bignum :create_time, null: false
    end

    create_table(:transfer_identifier) do
      primary_key :id

      foreign_key :transfer_proposal_id, :transfer_proposal, null: false
      foreign_key :transfer_id, :transfer, null: false
    end

    create_table(:transfer_proposal_series) do
      primary_key :id

      foreign_key :transfer_proposal_id, :transfer_proposal, null: false

      # FIXME business rules / types for these:
      String :series_title
      String :disposal_class
      String :date_range
      String :accrual_details
      String :creating_agency
      String :mandate
      String :function
      String :system_of_arrangement
      String :composition
      String :estimated_quantity
    end

    create_table(:conversation) do
      primary_key :id

      foreign_key :transfer_id, :transfer_identifier, null: false

      String :message, text: true, null: false

      String :created_by, null: false
      Bignum :create_time, null: false
    end

    create_table(:transfer_file) do
      primary_key :id

      foreign_key :transfer_id, :transfer_identifier, null: false

      String :key, null: false
      String :role, null: false

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
