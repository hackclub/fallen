require "test_helper"

class UploadsTest < ActionDispatch::IntegrationTest
  test "a signed-in person can upload an image" do
    sign_in_as users(:member)
    assert_difference "ActiveStorage::Blob.count", 1 do
      post uploads_path, params: { file: fixture_file_upload("pixel.png", "image/png") }
    end
    assert_response :success
    blob = ActiveStorage::Blob.find_signed!(response.parsed_body["signed_id"])
    assert_equal "image/png", blob.content_type
  end

  test "the type comes from the bytes, not what the browser claims" do
    sign_in_as users(:member)
    html = Rack::Test::UploadedFile.new(StringIO.new(+"<html><script>alert(1)</script></html>"), "image/png", original_filename: "x.png")
    assert_no_difference "ActiveStorage::Blob.count" do
      post uploads_path, params: { file: html }
    end
    assert_response :unprocessable_content
  end

  test "needs a session" do
    assert_no_difference "ActiveStorage::Blob.count" do
      post uploads_path, params: { file: fixture_file_upload("pixel.png", "image/png") }
    end
    assert_redirected_to root_path
  end

  test "banned people cannot upload" do
    sign_in_as users(:banned)
    assert_no_difference "ActiveStorage::Blob.count" do
      post uploads_path, params: { file: fixture_file_upload("pixel.png", "image/png") }
    end
    assert_redirected_to sorry_path
  end
end
