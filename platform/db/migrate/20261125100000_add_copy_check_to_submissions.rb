# A copy check of a submission's design files against public repositories (CopyCheck), and the admin who compared
# a match by hand.
class AddCopyCheckToSubmissions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :submissions, :copy_check, :jsonb
    add_column :submissions, :copy_check_cleared_at, :datetime
    add_reference :submissions, :copy_check_cleared_by, index: { algorithm: :concurrently }
  end
end
