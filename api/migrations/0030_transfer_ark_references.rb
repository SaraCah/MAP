Sequel.migration do
  up do
    alter_table(:transfer) do
      add_column(:ark_references, String, text: true)
    end
  end

  down do
  end
end
