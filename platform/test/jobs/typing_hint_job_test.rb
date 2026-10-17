require "test_helper"

class TypingHintJobTest < ActiveJob::TestCase
  test "someone without projects gets a button to start one" do
    with_fake_slack do |slack|
      TypingHintJob.perform_now("U0NEWBIE", "CJOURNALS")
      hint = slack.calls_to(:chat_postEphemeral).first
      assert_equal "U0NEWBIE", hint[:user]
      assert_nil hint[:thread_ts]
      assert_includes hint[:blocks].last[:elements].first[:url], "/projects/new"
    end
  end

  test "someone with projects gets their threads and the reminder" do
    with_fake_slack do |slack|
      TypingHintJob.perform_now("U0MEMBER", "CJOURNALS")
      hint = slack.calls_to(:chat_postEphemeral).first
      assert_includes hint[:text], projects(:station).slack_url
      assert_includes hint[:text], projects(:station).title
      assert_not_includes hint[:text], projects(:unlinked).title
      assert_equal({ type: "mrkdwn", text: hint[:text] }, hint[:blocks].first[:text])
      assert_equal "mrkdwn", hint[:blocks].second[:elements].first[:type]
      assert_includes hint[:blocks].last[:elements].first[:url], "/projects/new"
    end
  end

  test "hints once per person while they keep typing" do
    with_cache(ActiveSupport::Cache::MemoryStore.new) do
      assert_equal 1, hints { 3.times { TypingHintJob.hint("U0MEMBER", "CJOURNALS") } }
      assert_equal 1, hints { TypingHintJob.hint("U0ADMIN", "CJOURNALS") }
    end
  end

  test "hints again once the hint would change" do
    with_cache(ActiveSupport::Cache::MemoryStore.new) do
      hints { TypingHintJob.hint("U0MEMBER", "CJOURNALS") }
      projects(:station).update!(title: "Weather station v2")
      assert_equal 1, hints { TypingHintJob.hint("U0MEMBER", "CJOURNALS") }
    end
  end

  test "hints again after anyone posts in the channel, and not after a post is deleted" do
    with_cache(ActiveSupport::Cache::MemoryStore.new) do
      hints { TypingHintJob.hint("U0NEWBIE", "CJOURNALS") }
      journal = projects(:station).journals.create!(user: users(:member), body: "wired it up", duration_minutes: 30, source: "slack", slack_channel_id: "CJOURNALS", slack_ts: "9999999999.000100")
      assert_equal 1, hints { TypingHintJob.hint("U0NEWBIE", "CJOURNALS") }

      journal.discard
      assert_equal 0, hints { TypingHintJob.hint("U0NEWBIE", "CJOURNALS") }
    end
  end

  private

  def hints(&block)
    with_fake_slack do |slack|
      block.call
      slack.calls_to(:chat_postEphemeral).size
    end
  end

  def with_cache(store)
    original = Rails.cache
    Rails.cache = store
    yield
  ensure
    Rails.cache = original
  end
end
