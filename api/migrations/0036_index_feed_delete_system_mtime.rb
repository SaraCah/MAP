Sequel.migration do
  up do
    alter_table(:index_feed_deletes) do
      add_column :system_mtime, Integer, :null => false, :default => Time.now.to_i
    end
  end
end
