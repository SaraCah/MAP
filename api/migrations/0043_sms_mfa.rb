Sequel.migration do

  up do
    alter_table(:user) do
      add_column :mfa_method, String, null: false, default: 'none'
      add_column :mfa_confirmed, Integer, null: false, default: 0
    end

    create_table(:mfa_sms) do
      primary_key :id

      foreign_key :user_id, :user, unique: true
      String :phone_number, null: false

      Bignum :create_time, null: false
      Bignum :modified_time, null: false
    end

    create_table(:mfa_challenge) do
      primary_key :id

      Integer :user_id, null: false
      String :key, null: false, unique: true
      String :type, null: false
      File :state, size: :medium, null: true
      String :status, null: false
      Integer :attempts, null: false, default: 0
      Bignum :expires_after, null: false
    end
  end

end
