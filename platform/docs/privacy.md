# Privacy requests

Fallen implements the [Hack Club privacy hub](https://yeet.hackclub.com/docs/deletions) endpoints:

- `POST /api/privacy/delete` deletes everything below. With `dry_run: true` it runs the same deletion and rolls it
  back, so it reports exactly what the real run will remove.
- `POST /api/privacy/export` runs the same thing and always rolls back. It never changes anything.

Audience: `fallen`. Base URL for the hub: the web service's public URL (not a frontend-only host).

Code: `Api::PrivacyController`, `PrivacyToken` (token checks, JWKS cache), `PrivacyRequest` (the deletion),
`PrivacyTokenUse` (seen `jti`s, pruned after a day). `PRIVACY_JWKS_URL` overrides the JWKS URL.

## Finding the person

Only from the token's `subject`: any `emails` (case-insensitive against `users.email`), `slack_id` against
`users.slack_id`, and `identity_id` against `users.hca_id`. Discarded accounts match too.

## Deleted

| What | Where |
| --- | --- |
| The account: name, email, avatar, Slack id, timezone, roles, HCA token, Slack user token or when they chose not to connect Slack, Lapse token, verification status, pet and when they last switched it, when they first watched it hatch, where they came from when they signed up (UTM tags, `ref`, the referring page without its query string, the page they landed on) | `users` |
| Their projects and journals (text, hours, the tracked time before each and whether the hours went over it, Lapse links, Slack message ids and text), project banners and journal photos | `projects`, `journals`, Active Storage |
| Which project teams they are on and the invites they sent or got | `project_members`, `project_invites` |
| Their Lapse timelapses as Fallen copied them (Lapse id, name, recorded time, visibility, video and thumbnail links). The videos stay on Lapse | `lapse_timelapses` |
| Slack thread replies not yet made into a journal (text, Slack message ids, photo names and links) | `journal_drafts` |
| Time in the Slack huddle (when they joined and left, how each time was known, how long they shared their screen or had their camera on, what they said they were working on and got done, how many of the counted hours they said were really work, and the Slack DMs that asked them), also rows from before they signed up that carry their Slack id | `huddle_sessions` |
| Slack's join and leave events for the huddle, by Slack id and time | `huddle_events` |
| The pet's timer: when they started and stopped the site's timer, what they said they would work on and got done with it and how many of its hours were really work, paused in the huddle, and their hourly check-ins (what they said they had got done so far, and the Slack DM that asked) | `timer_sessions`, `huddle_pauses`, `time_milestones` |
| XP earned, line by line (journal XP, bonuses, streak checks) | `xp_entries`, `users.xp` |
| Feature flags an admin turned on for them by name (their public id on the flag) | `flipper_gates` |
| Change history of everything above (PaperTrail copies of the rows) | `versions` |
| The account's row in Airtable (name, email, HCA and Slack ids, whether it is a trial account, XP, project, journal and hour counts, where they came from). It drops out on the next upload, within 5 minutes, since every upload replaces the table | Airtable Users table (`AirtableUsers`) |

Fallout's email link codes (`fallout_invites`) are HMACs of an email and code pair copied from Fallout's Airtable, not
anyone's account, and are replaced every 15 minutes.

Sessions are signed cookies holding the user id, so they stop working once the row is gone.

## Kept

| What | Why |
| --- | --- |
| History of changes the person made to other accounts as staff | Belongs to those accounts. `whodunnit` is set to null so it no longer points at the person. |
| Banned accounts | Kept as a placeholder with only the HCA id and ban flag, so the ban still applies if they sign in again. Name, email, avatar, pet, Slack id and tokens are wiped and the account's history is deleted. Its Airtable row shows the placeholder after the next upload. |

## Not covered

- Solid Queue job rows can hold a user's GlobalID (`gid://fallen/User/1`) or a raw Slack event payload until they
  are cleared (finished jobs after a day by default). They are not searched.
- The landing page's "Get started as" picture: a `SlackAvatarJob` row holds the email someone is signed in to Hack
  Club Auth with until it is cleared, and the cache keeps the Slack picture URL under a digest of the email for a day.
  Neither is searched.
- Getting started with just an email: the browser asks Hack Club Auth whether it has an account for the email before
  anything is sent here. Trial accounts made from it are `users` rows like any other and are matched by email. One
  that later signs in to a different HCA account is discarded, and still matched by its email.
- Sentry events and application logs are not touched. They expire on their own retention.
- Request timings for `/admin/insights` (`active_insights_requests`) keep the path, controller, status and timings,
  but no user, IP or user agent. They are deleted after 30 days.
- Lapse is its own service. The timelapses stay on the person's Lapse account, and disconnecting only forgets the token.
- A project someone else is still building on its team is not deleted: it goes to the teammate who joined first, and
  only the person's own journals on it are deleted. The project's title, description and banner stay with it.
- Slack itself is not ours to delete from. Project threads and journal messages stay in the workspace.
- Stray posts in the journals channel are deleted through Prometheus, which keeps their text in its private audit
  log channel. That log belongs to Prometheus, not Fallen.

When a feature adds a table, upload or external service that holds user data, add it to `PrivacyRequest` and to this
file. Delete files in external storage only on a real run, before the transaction commits.
