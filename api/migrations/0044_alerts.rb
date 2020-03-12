Sequel.migration do

    up do
        create_table(:alert) do
            primary_key :id

            String :message, text: true, null: false
            String :alert_name, null: false
        end
    end
end