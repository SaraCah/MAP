Sequel.migration do

  up do
    alter_table(:dbauth) do
      add_column :recovery_token, String, null: true, index: true
      add_column :recovery_token_issue_time, :Bignum, null: false, default: 0
    end
  end

end
