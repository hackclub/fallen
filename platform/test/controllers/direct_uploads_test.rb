require "test_helper"

class DirectUploadsTest < ActionDispatch::IntegrationTest
  BLOB = { filename: "photo.png", byte_size: 12, checksum: "abc", content_type: "image/png" }.freeze

  test "a signed-in person can start a direct upload" do
    sign_in_as users(:member)
    assert_difference "ActiveStorage::Blob.count", 1 do
      post rails_direct_uploads_path, params: { blob: BLOB }, as: :json
    end
    assert_response :success
  end

  test "needs a session" do
    assert_no_difference "ActiveStorage::Blob.count" do
      post rails_direct_uploads_path, params: { blob: BLOB }, as: :json
    end
    assert_response :unauthorized
  end

  test "banned people cannot upload" do
    sign_in_as users(:banned)
    assert_no_difference "ActiveStorage::Blob.count" do
      post rails_direct_uploads_path, params: { blob: BLOB }, as: :json
    end
    assert_response :unauthorized
  end
end
