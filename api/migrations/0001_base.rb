Sequel.migration do
  up do
    create_table(:user) do
      primary_key :id
      String :username, null: false, unique: true, size: 64
      String :name, null: false

      Bignum :create_time, null: false
      Bignum :modified_time, null: false
    end


    create_table(:dbauth) do
      primary_key :id
      foreign_key :user_id, :user
      String :pwhash, null: false
    end
  end
end
