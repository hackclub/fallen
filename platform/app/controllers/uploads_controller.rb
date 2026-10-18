# Journal photos and project banners, uploaded through Rails rather than straight to R2. Stands in for Active
# Storage's direct uploads until the bucket has a CORS rule; until then the browser can't PUT to it.
# The type comes from the file's bytes, never the browser's say-so, and nothing decodes the image.
class UploadsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; every action authorizes explicitly

  # Multipart overhead on top of the largest image.
  MAX_REQUEST_BYTES = Journal::MAX_IMAGE_BYTES + 64.kilobytes

  def create
    authorize current_user, :upload?
    return head(:content_too_large) if request.content_length.to_i > MAX_REQUEST_BYTES

    file = params.expect(:file)
    return render_error("No file") unless file.is_a?(ActionDispatch::Http::UploadedFile)
    return render_error("#{file.original_filename} is over 10 MB") if file.size > Journal::MAX_IMAGE_BYTES

    content_type = Marcel::MimeType.for(file.tempfile)
    file.tempfile.rewind
    return render_error("#{file.original_filename} is not a PNG, JPEG, GIF or WebP") unless content_type.in?(Journal::IMAGE_TYPES)

    blob = ActiveStorage::Blob.create_and_upload!(io: file.tempfile, filename: file.original_filename,
      content_type: content_type, identify: false)
    render json: { signed_id: blob.signed_id, filename: blob.filename.to_s }
  end

  private

  def render_error(message) = render(json: { error: message }, status: :unprocessable_content)
end
