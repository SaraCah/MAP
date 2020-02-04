Sequel.migration do

  up do
    alter_table(:transfer) do
      set_column_type :date_scheduled, :date
      set_column_type :date_received, :date
    end
  end

end
