# Posts a flagged WritingCheck to the private #fallen-ai-flags channel, posted or not, so staff can judge whether
# Pangram got it right. Once the writing becomes a journal anyway, says so in the post's thread.
class ReportWritingFlagJob < ApplicationJob
  queue_as :slack
  limits_concurrency key: ->(check) { check }, duration: 1.minute
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def self.channel_id = ENV["SLACK_AI_FLAGS_CHANNEL_ID"].presence

  def perform(check)
    return unless self.class.channel_id && SlackBot.configured? && check.flagged?

    if check.slack_ts.blank?
      response = SlackBot.client.chat_postMessage(channel: self.class.channel_id, text: summary(check), unfurl_links: false)
      check.update!(slack_ts: response["ts"])
    elsif check.journal
      SlackBot.client.chat_postMessage(channel: self.class.channel_id, thread_ts: check.slack_ts, text: outcome(check), unfurl_links: false)
    end
  end

  private

  def summary(check)
    user = check.user
    profile = Rails.application.routes.url_helpers.admin_user_url(user, host: ENV.fetch("APP_URL", "http://localhost:3000"))
    writing = SlackMessages.escape(Journal.written_text(check.body)).gsub(/^/, "> ")
    [
      ":robot_face: *#{percent(check.fraction_ai)} AI-generated*, #{percent(check.fraction_ai_assisted)} AI-assisted · " \
      "#{user.slack_mention} (<#{profile}|#{SlackMessages.escape(user.display_name)}>)",
      check.journal ? outcome(check) : "Not posted yet.",
      writing
    ].join("\n")
  end

  def outcome(check)
    how = check.insisted? ? "after holding “I wrote this myself”" : "without seeing the reminder"
    "Posted #{how}: <#{SlackMessages.journal_url(check.journal)}|journal>"
  end

  def percent(fraction) = "#{(fraction.to_f * 100).round}%"
end
