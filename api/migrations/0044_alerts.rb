Sequel.migration do

    up do
        create_table(:alert) do
            primary_key :id

            String :message, null: false
            String :alert_name, null: false
        end
    end
end