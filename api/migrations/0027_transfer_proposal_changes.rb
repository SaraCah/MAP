Sequel.migration do
  up do
    # give default values to newly mandatory fields
    self[:transfer_proposal]
      .where{ Sequel.|({estimated_quantity: nil}, {estimated_quantity: ''}) }
      .update(:estimated_quantity => 'N/A')
    self[:transfer_proposal_series]
      .where{ Sequel.|({series_title: nil}, {series_title: ''}) }
      .update(:series_title => 'N/A')
    self[:transfer_proposal_series]
      .where{ Sequel.|({date_range: nil}, {date_range: ''}) }
      .update(:date_range => 'N/A')
    self[:transfer_proposal_series]
      .where{ Sequel.|({disposal_class: nil}, {disposal_class: ''}) }
      .update(:disposal_class => 'N/A')
    self[:transfer_proposal_series]
      .where{ Sequel.|({system_of_arrangement: nil}, {system_of_arrangement: ''}) }
      .update(:system_of_arrangement => 'unknown')


    alter_table(:transfer_proposal) do
      add_column(:description, String, text: true)
      set_column_not_null(:estimated_quantity)
    end

    alter_table(:transfer_proposal_series) do
      add_column(:description, String, text: true, null: false)
      add_column(:accrual, Integer, null: false, default: 0)
      set_column_not_null(:series_title)
      set_column_not_null(:date_range)
      set_column_not_null(:disposal_class)
      set_column_not_null(:system_of_arrangement)
    end

  end
end
