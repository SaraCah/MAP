Sequel.migration do

  up do
    DEFAULT_POSITION = 'Not yet provided'

    alter_table(:user) do
      add_column(:position, String, null: true)
    end

    existing_positions = self[:agency_user]
                          .filter(Sequel.~(:position => DEFAULT_POSITION))
                          .map {|row| [row[:user_id], row[:position]]}.to_h

    existing_positions.each do |user_id, position|
      self[:user]
        .filter(:id => user_id)
        .update(:position => position)
    end

    self[:user]
      .filter(:position => nil)
      .update(:position => DEFAULT_POSITION)

    alter_table(:user) do
      set_column_not_null(:position)
    end

    alter_table(:agency_user) do
      drop_column(:position)
    end
  end

end
