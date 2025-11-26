# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: "", limit: 255
      t.string :encrypted_password, null: false, default: "", limit: 255

      ## Recoverable
      t.string   :reset_password_token, limit: 255
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip, limit: 50
      t.string   :last_sign_in_ip, limit: 50

      ## Confirmable
      # t.string   :confirmation_token, limit: 255
      # t.datetime :confirmed_at
      # t.datetime :confirmation_sent_at
      # t.string   :unconfirmed_email, limit: 255 # Only if using reconfirmable

      ## Lockable
      # t.integer  :failed_attempts, default: 0, null: false # Only if lock strategy is :failed_attempts
      # t.string   :unlock_token, limit: 255 # Only if unlock strategy is :email or :both
      # t.datetime :locked_at

      ## Custom fields
      t.string :first_name, null: false, limit: 100
      t.string :last_name, null: false, limit: 100
      t.string :phone, limit: 20
      t.string :cpf, limit: 11
      t.string :user_type, null: false, default: "customer", limit: 20

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    # add_index :users, :confirmation_token,   unique: true
    # add_index :users, :unlock_token,         unique: true

    # Custom indexes for business logic
    add_index :users, :user_type
    add_index :users, :cpf, unique: true, where: "cpf IS NOT NULL"
    add_index :users, [ :last_name, :first_name ]
  end
end
