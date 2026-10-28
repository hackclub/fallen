# Restoring streaks (StreakAdjustment): excusing days, giving freezes, setting the multiplier and incidents, made from
# the streak card on /admin/users/:id and from /admin/streaks, and undoing them.
class Admin::StreakAdjustmentsController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Re-added below: Rails raises on the `except: :index` default without an index action
  after_action :verify_authorized

  def create
    fields = params.expect(adjustment: [ :user_id, *StreakAdjustment::FIELDS ])
    user = User.find_by_public_id!(fields[:user_id]) if fields[:user_id].present?
    adjustment = build_streak_adjustment(fields, user:)
    authorize [ :admin, adjustment ]

    if adjustment.apply!
      redirect_back_or_to back(adjustment), notice: adjustment.summary
    else
      inertia_errors(adjustment, fallback_location: back(adjustment))
    end
  end

  def destroy
    adjustment = StreakAdjustment.find_by_public_id!(params[:id])
    authorize [ :admin, adjustment ]

    if adjustment.undo!(true_user)
      redirect_back_or_to back(adjustment), notice: adjustment.incident? ? "Undone. Everyone it touched is being judged again in the background." : "Undone."
    else
      inertia_errors(adjustment, fallback_location: back(adjustment))
    end
  end

  private

  def back(adjustment) = adjustment.user ? admin_user_path(adjustment.user) : admin_streaks_path(tab: "incidents")
end
