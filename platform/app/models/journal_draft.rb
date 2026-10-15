# Replies a project's owner posts in its Slack thread, waiting for them to say what they were: one journal (however
# many messages it took), photos for a journal, or just chat. MessageEvent collects them, JournalPromptJob asks once
# the person stops posting, JournalDraftAction acts on the answer. Each part is { ts, text, files }.
# == Schema Information
#
# Table name: journal_drafts
#
#  id         :bigint           not null, primary key
#  parts      :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_journal_drafts_on_parts                   (parts jsonb_path_ops) USING gin
#  index_journal_drafts_on_project_id_and_user_id  (project_id,user_id) UNIQUE
#  index_journal_drafts_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class JournalDraft < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :jdr

  # How long someone has to stop posting before Fallen asks again about messages added to a draft.
  ASK_AFTER = 8.seconds
  # An unanswered draft this old is a different conversation: the next reply starts over instead of joining it.
  STALE_AFTER = 12.hours

  belongs_to :project
  belongs_to :user

  def self.containing(ts) = where("parts @> CAST(? AS jsonb)", [ { ts: ts } ].to_json)

  # Adds a reply to the person's open draft on the project, starting one if needed.
  def self.collect(project, user, ts:, text:, files: [])
    draft = find_or_create_by!(project: project, user: user)
    draft.with_lock do
      draft.parts = [] if draft.updated_at < STALE_AFTER.ago
      draft.parts += [ { "ts" => ts, "text" => text, "files" => files } ] unless draft.includes?(ts)
      draft.save!
    end
    draft
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def includes?(ts) = parts.any? { |part| part["ts"] == ts }
  def last_ts = parts.last&.dig("ts")
  def text = Journal.body_from(parts)
  def written? = text.present?
  def files = parts.flat_map { |part| part["files"] || [] }
  def message_count = parts.size

  def previous_journal = project.journals.kept.where(user: user).newest_first.first

  # Returns the journal, saved or holding the errors to show.
  def journal!(duration:, lapse_url: nil)
    journal = project.journals.build(
      user: user, body: text, duration: duration, lapse_url: lapse_url, source: "slack",
      slack_channel_id: project.slack_channel_id, slack_ts: parts.first["ts"], slack_parts: parts.map { |part| part.slice("ts", "text") }
    )
    transaction { destroy! if journal.save }
    journal
  end

  def edit(ts, text)
    update!(parts: parts.map { |part| part["ts"] == ts ? part.merge("text" => text) : part })
  end

  # Drops the parts up to `upto` (the newest one the person was shown) that aren't in `kept`. Parts posted after
  # stay, since the person hasn't seen them yet. Destroys the draft when nothing is left.
  def keep_only(kept, upto:)
    remaining = parts.reject { |part| part["ts"].to_d <= upto.to_d && !kept.include?(part["ts"]) }
    remaining.empty? ? destroy! : update!(parts: remaining)
  end

  def remove(ts)
    remaining = parts.reject { |part| part["ts"] == ts }
    remaining.empty? ? destroy! : update!(parts: remaining)
  end
end
