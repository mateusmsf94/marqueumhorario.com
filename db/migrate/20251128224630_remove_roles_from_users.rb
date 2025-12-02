class RemoveRolesFromUsers < ActiveRecord::Migration[8.1]
  def change
    # Remove the GIN index first
    remove_index :users, :roles

    # Remove the roles column
    remove_column :users, :roles, :string, array: true, default: ['customer'], null: false
  end
end
