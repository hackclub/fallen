require "test_helper"

# == Schema Information
#
# Table name: lapse_timelapses
#
#  id               :bigint           not null, primary key
#  duration_seconds :integer          default(0), not null
#  name             :string
#  playback_url     :string
#  recorded_at      :datetime
#  thumbnail_url    :string
#  visibility       :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  journal_id       :bigint
#  lapse_id         :string           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_lapse_timelapses_on_journal_id   (journal_id)
#  index_lapse_timelapses_on_lapse_id     (lapse_id) UNIQUE
#  index_lapse_timelapses_on_recorded_at  (recorded_at)
#  index_lapse_timelapses_on_user_id      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (journal_id => journals.id)
#  fk_rails_...  (user_id => users.id)
#
class LapseTimelapseTest < ActiveSupport::TestCase
  setup { users(:member).update!(lapse_token: "lapse-token") }

  test "sync copies what Lapse has, drops what is gone and keeps what a journal uses" do
    used = lapse_timelapses(:hidden)
    old = projects(:station).journals.create!(user: users(:member), body: "old", duration_minutes: 30, images: [ photo ], discarded_at: Time.current)
    used.update!(journal: old)

    stub_method(Lapse, :timelapses, [ lapse_data("lapse_new", duration: 2700), lapse_data("lapse_desk", name: "Renamed", duration: 5400) ]) do
      LapseTimelapse.sync(users(:member))
    end

    member = users(:member).reload
    assert_equal %w[lapse_desk lapse_hidden lapse_new], member.lapse_timelapses.pluck(:lapse_id).sort
    assert_equal "Renamed", lapse_timelapses(:desk).reload.name
    assert_equal 45, member.lapse_timelapses.find_by!(lapse_id: "lapse_new").duration_minutes
    assert member.lapse_synced_at.present?
  end

  test "sync leaves a timelapse another account already has" do
    stub_method(Lapse, :timelapses, [ lapse_data("lapse_admins") ]) { LapseTimelapse.sync(users(:member)) }
    assert_equal users(:admin), lapse_timelapses(:admins).reload.user
  end

  test "an expired token disconnects Lapse" do
    original = Lapse.method(:timelapses)
    Lapse.define_singleton_method(:timelapses) { |_token| raise Lapse::Unauthorized }
    LapseTimelapse.sync(users(:member))
    assert_not users(:member).reload.lapse_connected?
  ensure
    Lapse.define_singleton_method(:timelapses, original)
  end

  test "only rendered timelapses of a minute or more can back a journal, whatever their visibility" do
    assert_nil lapse_timelapses(:desk).unusable_reason
    assert_nil lapse_timelapses(:hidden).unusable_reason, "private on Lapse is fine"
    assert_match(/rendering/, LapseTimelapse.new(visibility: "UNLISTED").unusable_reason)
    assert_match(/failed/, LapseTimelapse.new(visibility: "FAILED_PROCESSING").unusable_reason)
    assert_match(/minute/, LapseTimelapse.new(visibility: "PUBLIC", playback_url: "https://x.test", duration_seconds: 20).unusable_reason)
  end

  private

  def lapse_data(id, name: "Session", duration: 600)
    { "id" => id, "name" => name, "duration" => duration, "visibility" => "UNLISTED", "playbackUrl" => "https://cdn.lapse.test/#{id}.mp4", "createdAt" => 1.hour.ago.to_i * 1000 }
  end
end
