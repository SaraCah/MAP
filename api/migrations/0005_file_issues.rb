Sequel.migration do
  up do

    create_table(:file_issue_request) do
      primary_key :id

      foreign_key :agency_id, :agency, null: false
      foreign_key :agency_location_id, :agency_location, null: false

      String :request_type, null: false
      Integer :urgent, null: false, default: 0
      String :request_notes, text: true, null: false

      Integer :deliver_to_reading_room, null: false, default: 0
      String :delivery_authorizer

      String :digital_request_status
      String :physical_request_status

      String :created_by, null: false
      Bignum :create_time, null: false

      # This here for ArchivesSpace ASModel compatibility
      Integer :lock_version, :default => 1, :null => false
      DateTime :system_mtime, :index => true, :null => false
    end

    create_table(:file_issue_request_item) do
      primary_key :id

      foreign_key :file_issue_request_id, :file_issue_request, null: false

      String :aspace_record_type, null: false
      String :aspace_record_id, null: false

      String :request_type, null: false # digital or physical

      String :record_details, text: true
    end

    create_table(:file_issue) do
      primary_key :id

      foreign_key :agency_id, :agency, null: false
      foreign_key :agency_location_id, :agency_location, null: false

      foreign_key :file_issue_request_id, :file_issue_request

      String :request_type, null: false
      String :issue_type, null: false  # digital or physical

      Integer :urgent, null: false, default: 0
      Integer :deliver_to_reading_room, null: false, default: 0
      String :delivery_authorizer

      String :status, null: false

      Integer :checklist_request_submitted, null: false, default: 0
      Integer :checklist_files_dispatched, null: false, default: 0
      Integer :checklist_file_issue_summary_sent, null: false, default: 0
      Integer :checklist_loan_completed, null: false, default: 0 # link expired or load returned

      String :created_by, null: false
      Bignum :create_time, null: false

      # This here for ArchivesSpace ASModel compatibility
      Integer :lock_version, :default => 1, :null => false
      DateTime :system_mtime, :index => true, :null => false
    end

    create_table(:file_issue_item) do
      primary_key :id

      foreign_key :file_issue_id, :file_issue, null: false

      String :aspace_record_type, null: false
      String :aspace_record_id, null: false

      String :record_details, text: true

      String :dispatch_date
      String :loan_expiry_date
      String :returned_date
      Integer :overdue, null: false, default: 0
      Integer :extension_requested, null: false, default: 0
      String :requested_extension_date
    end

    alter_table(:handle) do
      add_foreign_key(:file_issue_request_id, :file_issue_request, null: true)
      add_foreign_key(:file_issue_id, :file_issue, null: true)
    end

    create_table(:index_feed) do
      primary_key :id

      Integer :lock_version, :null => false
      Integer :record_id, :null => false
      Integer :repo_id, :null => false
      String :record_type, :null => false
      String :record_uri, :size => 64, :null => false, :unique => true
      File :blob, :size => :medium, :null => false
    end
  end

end
