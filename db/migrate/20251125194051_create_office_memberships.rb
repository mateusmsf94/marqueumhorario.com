class CreateOfficeMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :office_memberships, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :office, type: :uuid, null: false, foreign_key: true
      t.string :role, limit: 50, default: "member", null: false
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end

    # Ensure a user can only be a member of an office once
    add_index :office_memberships, [ :user_id, :office_id ], unique: true,
              name: "index_office_memberships_unique_user_office"

    # Common query patterns
    add_index :office_memberships, [ :office_id, :is_active ]
    add_index :office_memberships, [ :user_id, :is_active ]
  end
end
