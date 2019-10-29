Sequel.migration do
  up do

    alter_table(:dbauth) do
      drop_column(:rate_limit_expiry_time)
    end

    create_table(:rate_limit) do
      primary_key :id

      String :key, null: false, unique: true
      Bignum :rate_limit_expiry_time, default: 0, index: true
    end
  end
end
