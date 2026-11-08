# Both off until an admin turns them on at /admin/flags: design_submissions shows the Submit button
# (SubmissionsController::FLAG), hcb_auto_grants sends funding as soon as a design is approved (GrantPayout::FLAG).
class AddDesignSubmissionFlags < ActiveRecord::Migration[8.1]
  def up
    %w[design_submissions hcb_auto_grants].each { |key| Flipper.add(key) }
  end

  def down
    %w[design_submissions hcb_auto_grants].each { |key| Flipper.remove(key) }
  end
end
