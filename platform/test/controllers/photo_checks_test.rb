require "test_helper"

class PhotoChecksTest < ActionDispatch::IntegrationTest
  test "names the draft photos already on another journal, and ones that no longer exist" do
    sign_in_as users(:member)
    posted, fresh = photo, photo("fresh.png")
    [ posted, fresh ].each { |blob| blob.update!(metadata: blob.metadata.merge(Journal::UPLOADER_KEY => users(:member).id)) }
    projects(:station).journals.create!(user: users(:member), body: journal_text, duration: "1", images: [ posted ])

    post photo_checks_path, params: { ids: [ posted.signed_id, fresh.signed_id, "gone" ] }, as: :json
    assert_response :success
    assert_equal [ posted.signed_id, "gone" ], response.parsed_body["taken"]
  end

  test "a photo already on the journal being edited stays usable on it" do
    sign_in_as users(:member)
    image = photo
    image.update!(metadata: image.metadata.merge(Journal::UPLOADER_KEY => users(:member).id))
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text, duration: "1", images: [ image ])

    post photo_checks_path, params: { ids: [ image.signed_id ], journal: journal.public_id }, as: :json
    assert_equal [], response.parsed_body["taken"]
  end

  test "someone else's journal doesn't make its photos usable" do
    image = photo
    journal = projects(:station).journals.create!(user: users(:member), body: journal_text, duration: "1", images: [ image ])
    sign_in_as users(:admin)

    post photo_checks_path, params: { ids: [ image.signed_id ], journal: journal.public_id }, as: :json
    assert_equal [ image.signed_id ], response.parsed_body["taken"]
  end
end
