Sequel.migration do
  up do
    alter_table(:user) do
      add_column(:email, String, null: true)
    end

    self[:user]
      .update(:email => 'snappy@theturtle.com')

    alter_table(:user) do
      set_column_not_null(:email)
    end


    alter_table(:agency_user) do
      add_column(:position, String, null: true)
    end

    self[:agency_user]
      .update(:position => 'Not yet provided')

    alter_table(:agency_user) do
      set_column_not_null(:position)
    end

  end
end
