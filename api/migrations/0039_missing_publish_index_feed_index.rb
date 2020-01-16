Sequel.migration do
  up do
    alter_table(:index_feed_publish_metadata) do
      add_index([:record_uri], name: "map_ifpm_record_uri")
    end
  end
end
