# Keeps the YSWS table's justification as Fallen's part plus the one staff write by hand (YswsSubmission
# .join_justifications, config/recurring.yml). Does nothing until the table is configured.
class JoinYswsJustificationsJob < ApplicationJob
  queue_as :background
  limits_concurrency to: 1, key: "ysws_justifications", duration: 10.minutes

  def perform = YswsSubmission.join_justifications
end
