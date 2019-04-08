Sequel.migration do
  up do
    create_table(:user) do
      primary_key :id
      String :username, null: false, unique: true, size: 64
      String :name, null: false

      Integer :admin, null: false, default: 0

      Bignum :create_time, null: false
      Bignum :modified_time, null: false
    end

    create_table(:dbauth) do
      primary_key :id
      foreign_key :user_id, :user
      String :pwhash, null: false
    end

    create_table(:session) do
      primary_key :id
      String :session_id, :unique => true, :null => false, size: 64
      String :username, :null => false
      Bignum :create_time, null: false
      Bignum :last_used_time, null: false

      String :session_data, :null => true, :text => true
    end

  end
end
