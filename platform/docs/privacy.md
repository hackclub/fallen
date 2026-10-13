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
| The account: name, email, avatar, Slack id, timezone, roles, HCA token, Slack user token, verification status | `users` |
| Their projects and journals (text, hours, Lapse links, Slack message ids) and journal photos | `projects`, `journals`, Active Storage |
| Change history of the account, projects and journals (PaperTrail copies of the rows) | `versions` |

Sessions are signed cookies holding the user id, so they stop working once the row is gone.

## Kept

| What | Why |
| --- | --- |
| History of changes the person made to other accounts as staff | Belongs to those accounts. `whodunnit` is set to null so it no longer points at the person. |
| Banned accounts | Kept as a placeholder with only the HCA id and ban flag, so the ban still applies if they sign in again. Name, email, avatar, Slack id and tokens are wiped and the account's history is deleted. |

## Not covered

- Solid Queue job rows can hold a user's GlobalID (`gid://fallen/User/1`) or a raw Slack event payload until they
  are cleared (finished jobs after a day by default). They are not searched.
- Sentry events and application logs are not touched. They expire on their own retention.
- Slack itself is not ours to delete from. Project threads and journal messages stay in the workspace.

When a feature adds a table, upload or external service that holds user data, add it to `PrivacyRequest` and to this
file. Delete files in external storage only on a real run, before the transaction commits.
