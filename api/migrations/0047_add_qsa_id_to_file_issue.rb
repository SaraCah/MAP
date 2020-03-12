Sequel.migration do

  up do
    alter_table(:file_issue) do
      add_column(:qsa_id, Integer, :index => true, :null => true)
    end

    self[:file_issue].each do |obj|
      self[:file_issue].filter(:id => obj[:id]).update(:qsa_id => :id)
    end
  end

  down do
  end

end
