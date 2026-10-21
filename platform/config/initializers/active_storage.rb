# Uploads go through UploadsController, which checks the type, size and bytes. Rails mounts its own direct upload
# endpoint without any of that (it even takes client metadata that can skip identification), so it is closed.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.before_action { head :not_found }
end

# Rails queues one analyze job per attachment as each commits, an insert apiece. Journals queue theirs together
# instead (Journal#analyze_images_later).
module AnalyzeJournalImagesTogether
  private

  def analyze_blob_later
    super unless record_type == "Journal" && name == "images"
  end
end

Rails.application.config.to_prepare do
  ActiveStorage::Attachment.prepend(AnalyzeJournalImagesTogether) unless ActiveStorage::Attachment < AnalyzeJournalImagesTogether
end
