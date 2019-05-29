Sequel.migration do
  up do

    alter_table(:index_feed) do
      drop_column :lock_version
      add_column :system_mtime, Integer, :null => false, :default => 0
    end

  end

end
