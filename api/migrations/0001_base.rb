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
      foreign_key :user_id, :user, :unique => true
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

    create_table(:agency) do
      primary_key :id

      Integer :aspace_agency_id, :unique => true, null: false

      Bignum :create_time, null: false
      Bignum :modified_time, null: false
    end

    create_table(:agency_location) do
      primary_key :id

      foreign_key :agency_id, :agency

      String :name, null: false

      Bignum :create_time, null: false
      Bignum :modified_time, null: false
    end

    create_table(:group) do
      primary_key :id

      foreign_key :agency_id, :agency, null: false
      foreign_key :agency_location_id, :agency_location

      String :role, null: false

      Bignum :create_time, null: false
      Bignum :modified_time, null: false
    end

    create_table(:group_user) do
      primary_key :id

      foreign_key :user_id, :user, null: false
      foreign_key :group_id, :group, null: false

      Bignum :create_time, null: false
      Bignum :modified_time, null: false
    end
  end
end
