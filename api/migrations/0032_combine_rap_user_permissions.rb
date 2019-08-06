require_relative '../app/storage/db_connection'

Sequel.migration do
  up do
    # New column: allow_set_and_change_raps
    # Replaces: allow_set_raps and allow_change_raps
    alter_table(:agency_user) do
      add_column(:allow_set_and_change_raps, Integer, null: false, default: 0)
    end

    self[:agency_user]
      .filter(Sequel.|(:allow_set_raps => 1, :allow_change_raps => 1))
      .update(:allow_set_and_change_raps => 1)

    alter_table(:agency_user) do
      drop_column(:allow_set_raps)
      drop_column(:allow_change_raps)
    end
  end
end
