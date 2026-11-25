# Design reviews (Submission) and journal reviews (ProgressReview) each reviewer has done, most first.
class Admin::ReviewLeaderboardController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #show authorizes explicitly

  def show
    authorize [ :admin, :review_leaderboard ]
    range = ProgramStats::RANGES.key?(params[:range]) ? params[:range] : "all"

    render inertia: "Admin/ReviewLeaderboard/Show", props: {
      range:,
      ranges: ProgramStats::RANGES.keys,
      rows: InertiaRails.defer { rows(ProgramStats::RANGES[range]&.days&.ago) }
    }
  end

  private

  # Dismissals aren't counted (ProgressReview.reviews). A design review counts when it was decided, signed off or not,
  # for the reviewer who made it.
  def rows(since)
    design = tally(Submission.decided, :decided_at, since)
    journal = tally(ProgressReview.reviews, :created_at, since)
    users = User.where(id: design.keys | journal.keys).index_by(&:id)

    (design.keys | journal.keys).filter_map { |id| users[id] && { id: users[id].public_id, name: users[id].display_name, design: design.fetch(id, 0), journal: journal.fetch(id, 0) } }
      .sort_by { [ -(it[:design] + it[:journal]), it[:name] ] }
  end

  def tally(scope, column, since)
    scope = scope.where.not(reviewer_id: nil)
    scope = scope.where(column => since..) if since
    scope.group(:reviewer_id).count
  end
end
