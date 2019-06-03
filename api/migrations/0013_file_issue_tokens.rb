Sequel.migration do
  up do
    create_table(:file_issue_token) do
      primary_key :id

      String :token_key, null: false
      Integer :aspace_digital_representation_id, null: false
      foreign_key :file_issue_id, :file_issue, null: false
      Bignum :dispatch_date, null: false
      Bignum :expire_date, null: false
    end
  end

end
