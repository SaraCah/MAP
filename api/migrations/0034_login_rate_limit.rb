Sequel.migration do
  up do

    alter_table(:dbauth) do
      add_column(:rate_limit_expiry_time, :bigint, default: 0)
    end
  end
end
