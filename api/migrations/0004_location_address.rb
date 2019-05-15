Sequel.migration do
  up do

    alter_table(:agency_location) do
      add_column(:delivery_address, String, text: true, null: true)
    end

  end
end
