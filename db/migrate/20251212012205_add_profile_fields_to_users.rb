class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slug, :string, limit: 100
    add_column :users, :bio, :text
    add_index :users, :slug, unique: true

    # Backfill slugs for existing users
    reversible do |dir|
      dir.up do
        User.find_each do |user|
          base_slug = "#{user.first_name}-#{user.last_name}".parameterize
          candidate = base_slug
          counter = 2

          while User.exists?(slug: candidate)
            candidate = "#{base_slug}-#{counter}"
            counter += 1
          end

          user.update_column(:slug, candidate)
        end
      end
    end

    change_column_null :users, :slug, false
  end
end
