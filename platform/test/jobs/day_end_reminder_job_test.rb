require "test_helper"

class DayEndReminderJobTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @member = users(:member)
    @admin = users(:admin)
    XpEntry.where(user: [ @member, @admin ]).update_all(day: Date.new(2026, 1, 1))
    DayEndReminder.create!(user: @member)
  end

  test "pings once in their team's channel when 4 hours are left in their day" do
    with_team_channels do |slack|
      travel_to(Time.utc(2026, 11, 5, 19, 59)) { run_job }
      assert_empty slack.calls_to(:chat_postMessage)

      travel_to(Time.utc(2026, 11, 5, 20, 0)) { run_job }
      travel_to(Time.utc(2026, 11, 5, 20, 15)) { run_job }
      message = slack.calls_to(:chat_postMessage).sole
      assert_equal "CLULU", message[:channel]
      assert_equal "Lulu", message[:username]
      assert_equal "<@U0MEMBER> About 4 hours left in your day and no journal yet :hm:  YOU GOT THIS!! :lulu-boba:", message[:text]
      assert_equal Date.new(2026, 11, 5), @member.day_end_reminder.reload.reminded_on

      travel_to(Time.utc(2026, 11, 6, 20, 0)) { run_job }
      assert_equal 2, slack.calls_to(:chat_postMessage).size, "pinged again the next day"
    end
  end

  test "follows their own timezone" do
    @member.update_columns(timezone: "Asia/Kolkata")
    with_team_channels do |slack|
      travel_to(Time.utc(2026, 11, 5, 14, 15)) { run_job }
      assert_empty slack.calls_to(:chat_postMessage), "7:45pm in Kolkata"

      travel_to(Time.utc(2026, 11, 5, 14, 30)) { run_job }
      assert_equal "CLULU", slack.calls_to(:chat_postMessage).sole[:channel]
    end
  end

  test "nobody whose journal counts for today, didn't opt in, or opted out" do
    @member.xp_entries.journals.first.update_columns(day: Date.new(2026, 11, 5))
    DayEndReminder.create!(user: @admin).destroy!
    with_team_channels do |slack|
      travel_to(Time.utc(2026, 11, 5, 21, 0)) { run_job }
      assert_empty slack.calls
    end
  end

  test "a journal still waiting for hours doesn't count, the way it doesn't for the streak" do
    @member.journals.first.update_columns(created_at: Time.utc(2026, 11, 5, 9, 0))
    with_team_channels do |slack|
      travel_to(Time.utc(2026, 11, 5, 21, 0)) { run_job }
      assert_match "<@U0MEMBER>", slack.calls_to(:chat_postMessage).sole[:text]
    end
  end

  test "a crowd due together is split across messages" do
    stub_const(DayEndReminderJob, :MENTIONS_PER_MESSAGE, 1) do
      users(:newcomer).update_columns(pet: "lulu", slack_id: "U0NEWCOMER")
      DayEndReminder.create!(user: users(:newcomer))
      with_team_channels do |slack|
        travel_to(Time.utc(2026, 11, 5, 20, 0)) { run_job }
        assert_equal [ [ "<@U0MEMBER>" ], [ "<@U0NEWCOMER>" ] ].to_set, slack.calls_to(:chat_postMessage).map { it[:text].scan(/<@\w+>/) }.to_set
      end
    end
  end

  test "people on the same team due together share a message; each team hears in its own channel" do
    teammate = users(:newcomer)
    teammate.update_columns(pet: "lulu", slack_id: "U0NEWCOMER")
    DayEndReminder.create!(user: teammate)
    DayEndReminder.create!(user: @admin)
    with_team_channels do |slack|
      travel_to(Time.utc(2026, 11, 5, 20, 0)) { run_job }
      messages = slack.calls_to(:chat_postMessage).index_by { it[:channel] }
      assert_equal %w[CLULU CSAMI], messages.keys.sort
      assert_match "<@U0MEMBER> <@U0NEWCOMER>", messages["CLULU"][:text]
      assert_match "<@U0ADMIN>", messages["CSAMI"][:text]
      assert messages["CSAMI"][:text].end_with?("YOU GOT THIS!! :sami-bao:"), "Sami signs off with its own emoji"
      assert messages["CLULU"][:text].end_with?("YOU GOT THIS!! :lulu-boba:")
    end
  end

  test "waits and tries again when Slack says to slow down, so nobody already claimed is dropped" do
    with_team_channels do |slack|
      tries = 0
      limited = Slack::Web::Api::Errors::TooManyRequestsError.new(Struct.new(:headers).new({ "retry-after" => "1" }))
      slack.define_singleton_method(:chat_postMessage) do |**args|
        (tries += 1) == 1 ? raise(limited) : method_missing(:chat_postMessage, **args)
      end
      waits = []
      job = DayEndReminderJob.new
      job.define_singleton_method(:sleep) { |seconds| waits << seconds }

      travel_to(Time.utc(2026, 11, 5, 20, 0)) { job.perform_now }
      assert_equal [ 1 ], waits
      assert_equal "CLULU", slack.calls_to(:chat_postMessage).sole[:channel]
    end
  end

  test "a Slack outage on one message is reported and the other teams still hear" do
    DayEndReminder.create!(user: @admin)
    with_team_channels do |slack|
      slack.define_singleton_method(:chat_postMessage) do |**args|
        args[:channel] == "CLULU" ? raise(Slack::Web::Api::Errors::UnavailableError.new(nil)) : method_missing(:chat_postMessage, **args)
      end

      assert_error_reported(Slack::Web::Api::Errors::UnavailableError) do
        travel_to(Time.utc(2026, 11, 5, 20, 0)) { run_job }
      end
      assert_equal [ "CSAMI" ], slack.calls_to(:chat_postMessage).pluck(:channel)
    end
  end

  test "a team with no channel set is reported, and its people stay unmarked for when it is" do
    with_fake_slack do |slack|
      with_env("SLACK_LULU_CHANNEL_ID" => nil, "SLACK_SAMI_CHANNEL_ID" => "CSAMI") do
        assert_error_reported(ArgumentError) do
          travel_to(Time.utc(2026, 11, 5, 20, 0)) { run_job }
        end
      end
      assert_empty slack.calls_to(:chat_postMessage)
      assert_nil @member.day_end_reminder.reload.reminded_on
    end
  end

  test "the time left is rounded to read naturally" do
    reminder = @member.day_end_reminder
    { [ 20, 0 ] => "4 hours", [ 20, 15 ] => "4 hours", [ 20, 40 ] => "3.5 hours", [ 23, 20 ] => "45 minutes", [ 23, 55 ] => "15 minutes" }.each do |(hour, minute), words|
      assert_equal words, SlackMessages.duration_words(reminder.minutes_left(Time.utc(2026, 11, 5, hour, minute))), "at #{hour}:#{minute}"
    end
  end

  # Four for the run, plus one per message posted to remember it (DayEndReminderPingJob), never one per person.
  test "the same queries however many are due" do
    users(:newcomer).update_columns(pet: "lulu", slack_id: "U0NEWCOMER")
    [ users(:newcomer), @admin ].each { DayEndReminder.create!(user: it) }
    with_team_channels do |slack|
      travel_to(Time.utc(2026, 11, 5, 20, 0)) { assert_query_budget(4 + 2) { run_job } }
      assert_equal 2, slack.calls_to(:chat_postMessage).size
    end
  end

  test "the announcement goes to the channel it's given, as lulu, with both buttons" do
    with_fake_slack do |slack|
      DayEndReminderAnnouncementJob.perform_now("CBULLETIN")
      post = slack.calls_to(:chat_postMessage).sole
      assert_equal [ "CBULLETIN", "Lulu" ], post.values_at(:channel, :username)
      assert_match "Hey, it's Lulu :lulu-boba:! Sami :sami-bao: (yuck) and I are both trying to win this week", post[:text]
      assert_match ":fallen-star:Press *JOIN* and we'll notify you in your team channel at 8pm (your time) if you haven't journaled yet!", post[:text]
      buttons = post[:blocks].last[:elements]
      assert_equal %w[day_end_reminder:on day_end_reminder:off], buttons.pluck(:action_id)
      assert_equal %w[JOIN Leave], buttons.map { it[:text][:text] }
    end
  end

  private

  def run_job = DayEndReminderJob.perform_now

  def with_team_channels(&)
    with_fake_slack { |slack| with_env("SLACK_LULU_CHANNEL_ID" => "CLULU", "SLACK_SAMI_CHANNEL_ID" => "CSAMI") { yield slack } }
  end
end
