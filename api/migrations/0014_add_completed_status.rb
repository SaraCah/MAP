Sequel.migration do
  up do
    alter_table(:transfer) do
      add_column(:checklist_transfer_completed, Integer, :null => false, :default => 0)
    end
  end
end
