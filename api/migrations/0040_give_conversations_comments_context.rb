Sequel.migration do
  up do
    alter_table(:conversation) do
      add_column(:source_system, String, null: true)
    end

    self[:conversation]
      .filter(:created_by => self[:user].select(:username))
      .update(:source_system => 'ARCHIVES_GATEWAY')

    self[:conversation]
      .filter(:created_by => 'admin')
      .update(:source_system => 'ARCHIVESSPACE')

    self[:conversation]
      .filter(:source_system => nil)
      .update(:source_system => 'ARCHIVESSPACE')

    alter_table(:conversation) do
      set_column_not_null(:source_system)
    end
  end
end
