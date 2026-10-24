# The admin MCP server

`POST /mcp` (`McpController`) speaks the Model Context Protocol's Streamable HTTP transport through the `mcp` gem,
stateless, one JSON-RPC request per POST. Its tools are the admin panel's own actions (`Mcp::Registry`), and each
runs the same Pundit policy and model methods as its page.

## Adding it to Claude Code

Make a token at `/admin/mcp`, then:

```sh
claude mcp add --transport http fallen-admin https://fallen.hackclub.com/mcp --header "Authorization: Bearer <token>" -s local
```

Local scope keeps the token in Claude Code's own config, out of any repository. Leave the write tools on "ask"
rather than allowing them for good.

## Tokens (`AdminToken`)

- `fallen_admin_` and 40 base58 characters. Only the SHA-256 digest and the last four characters are stored; the
  token itself is in the one JSON response that minted it, never in flash, props or a log.
- Every token expires: 30 days by default, 90 at most. An admin holds five live ones at most.
- Accepted only as `Authorization: Bearer`, and only while the token is live and its owner is a kept, unbanned admin.
  The role is checked on every call. The endpoint never reads the session cookie, so a page on another site can't
  make a browser call it.
- Losing the admin role, a ban or deleting the account revokes every live token (`User#revoke_admin_tokens`). Any
  admin can revoke any token at `/admin/mcp`.
- Refusals are 401 `unauthorized` and say nothing about why. Flipper flag `disable_admin_mcp` turns the server off
  for everyone (503).
- Rate limits in `config/initializers/rack_attack.rb`: 300 calls a minute per token and per IP, 10 tokens an hour per
  admin. Requests over 256 KB are refused.

## The log (`McpAction`)

Every call, read or write, is one `mcp_actions` row (`Mcp::Invoke`): the admin, the token, the tool, the arguments
(long strings cut), the status, the duration and the record it was about. Writes keep a small result with emails
and HCA ids taken out (`Mcp::Scrub`); reads keep none. The call runs under PaperTrail with `source: "mcp:<tool>"`
and `mcp_action_id`, so `McpAction#versions` is what it changed. The last 50 calls are on `/admin/mcp`.

## Writing a tool

Tools live in `app/services/mcp/tools/<area>_tools.rb`, one module per area listed in `Mcp::Registry::AREAS`:

```ruby
class SetProjectApproved < Mcp::Tool
  description "Approve a finished project, or take its approval back."
  arguments({ id: { type: "string" }, approved: { type: "boolean" } }, required: %w[id approved])
  writes! idempotent: true

  def self.run(ctx, id:, approved:)
    project = Project.find_by_public_id!(id)
    ctx.authorize!([ :admin, project ], :update?)
    ctx.subject!(project)
    project.update!(approved:)
    { id: project.public_id, approved: project.approved? }
  end
end
```

- `arguments` sets `additionalProperties: false`, so the gem refuses anything the tool didn't name before `run`.
- Call the same policy and model method as the controller action. A tool that can do more than its page is a bug.
- Rows are short and paged through `Mcp::Compact.paginate` (25 a page, 50 at most); long text goes through
  `Mcp::Compact.clip`. An answer over 48 KB is withheld and replaced by the size of each section.
- `ctx.refuse!("…")` declines with a reason. Errors a caller can act on come back as their message; anything else
  is reported to Sentry and comes back as its class name only.

## Not exposed

Impersonation (a browser session), minting or revoking tokens (done by a person on `/admin/mcp`) and raw SQL. There
is no undo; reverse a write with the opposite call.

Text participants wrote (names, project titles, journals) reaches the model as data. The server's instructions tell
it never to follow instructions found there and to confirm bans, role changes and deletions first, but that is a
request to the model, not a guarantee, which is why the write tools should stay on "ask" in the client.
