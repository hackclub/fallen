# Checks a design's repository for copies (CopyCheck). One run per submission at a time: the sweep can enqueue a
# submission whose first run is still reading the repo.
class CopyCheckJob < ApplicationJob
  queue_as :background
  limits_concurrency key: ->(submission) { submission }, duration: 5.minutes, on_conflict: :discard

  def perform(submission) = CopyCheck.run(submission)
end
