Sequel.migration do
  up do

    alter_table(:transfer) do
      add_column(:import_job_uri, String, :null => true)
    end

  end
end
