Sequel.migration do
  up do

    alter_table(:search_request) do
      add_column(:date_details, String, text: true)
      add_column(:purpose, String)
    end

  end
end
