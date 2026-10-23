# Journal photos and project banners, which the browser PUTs straight to R2 in two steps:
#
# 1. create: checks the declared type and size and returns a presigned PUT bound to that type, size and MD5, plus
#    a token that only this controller accepts. Active Storage's own endpoint is closed (initializers/active_storage.rb).
# 2. update: once the PUT is done, reads the first bytes back and only then hands out the blob's signed id, noting
#    who uploaded it (Journal.reused_uploads?).
#
# The type comes from the file's bytes, never the browser's say-so, and nothing decodes the image.
class UploadsController < ApplicationController
  include ActiveStorage::SetCurrent # The Disk service (dev, test) builds its upload URL from the request host
  allow_trial_access only: %i[create update] # Project banners, made during the onboarding
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; every action authorizes explicitly

  TOKEN_PURPOSE = :upload

  def create
    authorize current_user, :upload?
    blob_args = params.expect(blob: %i[filename byte_size checksum content_type])
    filename = blob_args[:filename].to_s
    return render_error("#{filename} is over 10 MB") unless blob_args[:byte_size].to_i.between?(1, Journal::MAX_IMAGE_BYTES)
    return render_error("#{filename} is not a PNG, JPEG, GIF or WebP") unless blob_args[:content_type].in?(Journal::IMAGE_TYPES)

    # No client metadata: it could set "identified" and skip the check in update.
    blob = ActiveStorage::Blob.create_before_direct_upload!(filename:, byte_size: blob_args[:byte_size].to_i,
      checksum: blob_args[:checksum].to_s, content_type: blob_args[:content_type])
    token = blob.signed_id(purpose: TOKEN_PURPOSE, expires_in: 1.hour)
    render json: {
      filename: blob.filename.to_s,
      finish_url: upload_path(token),
      direct_upload: { url: blob.service_url_for_direct_upload, headers: blob.service_headers_for_direct_upload }
    }
  end

  def update
    authorize current_user, :upload?
    blob = ActiveStorage::Blob.find_signed(params[:id], purpose: TOKEN_PURPOSE)
    return head(:not_found) unless blob

    # Only the bytes: Active Storage's own identify falls back to the declared type when nothing matches.
    content_type = Marcel::MimeType.for(StringIO.new(blob.service.download_chunk(blob.key, 0...4.kilobytes)))
    unless content_type.in?(Journal::IMAGE_TYPES)
      blob.purge
      return render_error("#{blob.filename} is not a PNG, JPEG, GIF or WebP")
    end
    blob.metadata[Journal::UPLOADER_KEY] = current_user.id
    blob.update!(content_type:, identified: true)

    render json: { signed_id: blob.signed_id, filename: blob.filename.to_s }
  rescue ActiveStorage::FileNotFoundError
    render_error("#{blob.filename} didn't finish uploading")
  end

  private

  def render_error(message) = render(json: { error: message }, status: :unprocessable_content)
end
