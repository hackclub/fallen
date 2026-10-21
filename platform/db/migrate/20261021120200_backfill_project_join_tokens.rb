class BackfillProjectJoinTokens < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    Project.unscoped.where(join_token: nil).in_batches do |batch|
      batch.each { |project| project.update_column(:join_token, Project.generate_unique_secure_token) }
    end
  end

  def down; end
end
