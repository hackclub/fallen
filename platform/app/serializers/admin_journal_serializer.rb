# A journal as reviewers see it (Admin::ProjectsController): what the huddle and the site timer tracked before it
# was written, and whether its hours go over that and over its timelapses (Journal#hours_self_claimed).
class AdminJournalSerializer < JournalSerializer
  typelize tracked_text: [ :string, nullable: true ], hours_self_claimed: [ :boolean, nullable: true ]
  attributes :hours_self_claimed
  attribute(:tracked_text) { |journal| journal.tracked_minutes && Duration.format(journal.tracked_minutes) }
end
