class CreateProjectTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :project_members do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :project_members, %i[project_id user_id], unique: true

    create_table :project_invites do |t|
      t.references :project, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :project_invites, %i[project_id user_id], unique: true
  end
end
