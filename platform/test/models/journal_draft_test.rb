require "test_helper"

# == Schema Information
#
# Table name: journal_drafts
#
#  id            :bigint           not null, primary key
#  parts         :jsonb            not null
#  prompt_url    :string
#  prompt_url_at :datetime
#  timelapse_ids :jsonb            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  project_id    :bigint           not null
#  user_id       :bigint           not null
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
class JournalDraftTest < ActiveSupport::TestCase
  def file(id, mimetype: "image/png", size: 1000) = { "id" => id, "name" => "#{id}.png", "mimetype" => mimetype, "size" => size }

  test "only photos that will be copied over count toward a journal's hours" do
    used = ActiveStorage::Blob.create_and_upload!(io: file_fixture("pixel.png").open, filename: "used.png", content_type: "image/png", metadata: { slack_file_id: "FUSED" })
    journals(:first).images.attach(used)

    files = [ file("FOK"), file("FOK"), file("FBIG", size: Journal::MAX_IMAGE_BYTES + 1), file("FPDF", mimetype: "application/pdf"), file("FUSED") ]
    draft = JournalDraft.collect(projects(:station), users(:member), ts: "1700000099.000100", text: "Soldered", files: files)

    assert_equal [ "FOK" ], draft.photos.map { |photo| photo["id"] }
  end
end
