# The admin whose approval sent a design out: the reviewer when an admin reviewed it, otherwise the admin who signed
# off a design reviewer's decision. Named in the YSWS justification (YswsJustification).
class AddSignedOffByToSubmissions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :submissions, :signed_off_by, index: { algorithm: :concurrently }
  end
end
