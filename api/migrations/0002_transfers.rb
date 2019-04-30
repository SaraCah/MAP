Sequel.migration do
  up do
    create_table(:transfer) do
      primary_key :id

      foreign_key :agency_id, :agency, null: false
      foreign_key :agency_location_id, :agency_location, null: false

      String :title, null: false

      String :csv_filename, null: false
      File :csv, :size => :medium, null: false
      String :status, null: false

      String :created_by, null: false
      Bignum :create_time, null: false
    end

    # create_table(:transfer_series) do
    #   primary_key :id
    # 
    #   foreign_key :transfer_id, :transfer, null: false
    # 
    #   # FIXME business rules / types for these:
    #   String :series_title
    #   String :disposal_class
    #   String :date_range
    #   String :accrual_details
    #   String :creating_agency
    #   String :mandate
    #   String :function
    #   String :system_of_arrangement
    #   String :composition
    #   String :estimated_quantity
    # end

    create_table(:conversation) do
      primary_key :id

      foreign_key :transfer_id, :transfer, null: false

      String :message, text: true, null: false

      String :created_by, null: false
      Bignum :create_time, null: false
    end
  end
end
