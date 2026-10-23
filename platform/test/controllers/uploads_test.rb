require "test_helper"

class UploadsTest < ActionDispatch::IntegrationTest
  PNG = Rails.root.join("test/fixtures/files/pixel.png").binread

  test "a signed-in person uploads an image in two steps" do
    sign_in_as users(:member)
    assert_difference "ActiveStorage::Blob.count", 1 do
      start_upload(PNG)
    end
    assert_response :success
    assert_nil response.parsed_body["signed_id"], "no usable id before the bytes are checked"

    finish_url = response.parsed_body["finish_url"]
    put_bytes(PNG)
    patch finish_url, as: :json
    assert_response :success
    blob = ActiveStorage::Blob.find_signed!(response.parsed_body["signed_id"])
    assert_equal "image/png", blob.content_type
    assert blob.identified?
    assert_equal users(:member).id, blob.metadata[Journal::UPLOADER_KEY]
  end

  test "the type comes from the bytes, not what the browser claims" do
    sign_in_as users(:member)
    html = +"<html><script>alert(1)</script></html>"
    start_upload(html)
    put_bytes(html)
    blob = ActiveStorage::Blob.last
    patch response.parsed_body["finish_url"], as: :json
    assert_response :unprocessable_content
    assert_not ActiveStorage::Blob.exists?(blob.id)
  end

  test "bytes with no recognisable type are refused too" do
    sign_in_as users(:member)
    start_upload("just some text")
    put_bytes("just some text")
    patch response.parsed_body["finish_url"], as: :json
    assert_response :unprocessable_content
  end

  test "finishing before the bytes arrive fails cleanly" do
    sign_in_as users(:member)
    start_upload(PNG)
    patch response.parsed_body["finish_url"], as: :json
    assert_response :unprocessable_content
  end

  test "a signed blob id is not an upload token" do
    sign_in_as users(:member)
    start_upload(PNG)
    patch upload_path(ActiveStorage::Blob.last.signed_id), as: :json
    assert_response :not_found
  end

  test "refuses types and sizes it would never accept" do
    sign_in_as users(:member)
    assert_no_difference "ActiveStorage::Blob.count" do
      start_upload(PNG, content_type: "image/svg+xml")
      assert_response :unprocessable_content
      start_upload(PNG, byte_size: Journal::MAX_IMAGE_BYTES + 1)
      assert_response :unprocessable_content
    end
  end

  test "client metadata cannot mark a blob as already checked" do
    sign_in_as users(:member)
    start_upload(PNG, metadata: { identified: true, analyzed: true })
    assert_not ActiveStorage::Blob.last.identified?
  end

  test "Active Storage's own direct upload endpoint is closed" do
    sign_in_as users(:member)
    assert_no_difference "ActiveStorage::Blob.count" do
      post rails_direct_uploads_path, params: { blob: blob_params(PNG) }, as: :json
    end
    assert_response :not_found
  end

  test "needs a session" do
    assert_no_difference "ActiveStorage::Blob.count" do
      start_upload(PNG)
    end
    assert_redirected_to root_path
  end

  test "banned people cannot upload" do
    sign_in_as users(:banned)
    assert_no_difference "ActiveStorage::Blob.count" do
      start_upload(PNG)
    end
    assert_redirected_to sorry_path
  end

  private

  def blob_params(bytes, **overrides)
    { filename: "x.png", byte_size: bytes.bytesize, checksum: OpenSSL::Digest::MD5.base64digest(bytes), content_type: "image/png", **overrides }
  end

  def start_upload(bytes, **overrides) = post(uploads_path, params: { blob: blob_params(bytes, **overrides) }, as: :json)

  def put_bytes(bytes)
    blob = ActiveStorage::Blob.last
    blob.service.upload(blob.key, StringIO.new(bytes), checksum: blob.checksum)
  end
end
