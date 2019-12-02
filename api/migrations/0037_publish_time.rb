Sequel.migration do
  up do
    create_table(:index_feed_publish_metadata) do
      primary_key :id

      String :record_type, null: false
      String :record_uri, null: false
      Integer :publish_time, null: false
    end

  end
end
