Sequel.migration do
  up do

    # add created_by tables that need it
    [:agency, :agency_location, :user].each do |table|
      alter_table(table) do
        add_column(:created_by, String)
      end

      # default created_by to admin
      self[table].update(:created_by => 'admin')

      # set column not-nullable
      alter_table(table) do
        set_column_not_null(:created_by)
      end
    end

    # add modified_by to tables that need it
    [:file_issue_request, :file_issue, :transfer_proposal, :transfer,
     :agency_location, :user, :agency].each do |table|
      alter_table(table) do
        add_column(:modified_by, String)
      end

      self[table].update(:modified_by => :created_by)

      # set column not-nullable
      alter_table(table) do
        set_column_not_null(:modified_by)
      end
    end

    # add modified_time to tables that need it
    [:file_issue_request, :file_issue, :transfer_proposal,
     :transfer].each do |table|
      alter_table(table) do
        add_column(:modified_time, :bigint)
      end

      self[table].update(:modified_time => :create_time)

      # set column not-nullable
      alter_table(table) do
        set_column_not_null(:modified_time)
      end
    end

  end
end
