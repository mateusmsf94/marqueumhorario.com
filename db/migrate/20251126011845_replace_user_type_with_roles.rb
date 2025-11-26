class ReplaceUserTypeWithRoles < ActiveRecord::Migration[8.1]
  def change
    # Remove the old user_type enum column
    remove_column :users, :user_type, :string

    # Add roles array column (PostgreSQL array support)
    add_column :users, :roles, :string, array: true, default: [ 'customer' ], null: false

    # Add index for array contains queries (efficient role checks)
    add_index :users, :roles, using: 'gin'
  end
end
