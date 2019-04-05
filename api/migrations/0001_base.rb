Sequel.migration do
  up do
    create_table(:hello) do
      primary_key :id
      String :message, null: false
    end
    self[:hello].insert(message: "world")
  end
end