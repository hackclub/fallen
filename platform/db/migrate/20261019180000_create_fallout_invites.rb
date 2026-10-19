class CreateFalloutInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :fallout_invites, id: false do |t|
      t.string :digest, null: false, primary_key: true
    end
  end
end
