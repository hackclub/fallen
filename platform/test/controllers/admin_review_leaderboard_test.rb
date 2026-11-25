require "test_helper"

class AdminReviewLeaderboardTest < ActionDispatch::IntegrationTest
  test "counts each reviewer's design and journal reviews, most first" do
    sign_in_as users(:admin)
    props = load_deferred(admin_review_leaderboard_path, "Admin/ReviewLeaderboard/Show", "rows")

    totals = props["rows"].map { it["design"] + it["journal"] }
    assert_equal totals.sort.reverse, totals
    assert_equal Submission.decided.where.not(reviewer_id: nil).count, props["rows"].sum { it["design"] }
    assert_equal ProgressReview.reviews.where.not(reviewer_id: nil).count, props["rows"].sum { it["journal"] }
  end

  test "a range leaves out older reviews" do
    sign_in_as users(:admin)
    props = load_deferred(admin_review_leaderboard_path(range: "7d"), "Admin/ReviewLeaderboard/Show", "rows")

    assert_equal "7d", props["range"]
    assert_equal Submission.decided.where(decided_at: 7.days.ago..).where.not(reviewer_id: nil).count, props["rows"].sum { it["design"] }
  end

  test "members are turned away" do
    sign_in_as users(:member)
    get admin_review_leaderboard_path
    assert_response :not_found
  end
end
