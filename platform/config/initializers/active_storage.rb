# Direct uploads (project banners, journal photos) are for signed-in people only. Rails mounts the endpoint
# without any authentication, so without this anyone could fill the bucket with blobs that never attach to anything.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.before_action do
    user = session[:user_id].presence && User.kept.find_by(id: session[:user_id])
    head :unauthorized if user.nil? || user.is_banned?
  end
end
