Sequel.migration do
  up do

    create_table(:mfa_keys) do
      primary_key :id

      foreign_key :user_id, :user, null: false

      String :key, null: false
    end
  end
end
