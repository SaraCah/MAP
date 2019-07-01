Sequel.migration do
  up do

    create_table(:search_request_file) do
      primary_key :id

      foreign_key :search_request_id, :search_request, null: false

      String :key, null: false
      String :filename, null: false

      String :mime_type, null: false

      String :created_by, null: false
      Bignum :create_time, null: false
    end

    drop_table(:search_request_item)
  end
end
