// How to add the admin MCP server (docs/mcp.md) to each client, shown once beside a new token.
export type McpClient = {
  key: string
  label: string
  where: string
  snippet: (url: string, token: string) => string
}

const SERVER = 'fallen-admin'

export const mcpClients: McpClient[] = [
  {
    key: 'claude-code',
    label: 'Claude Code',
    where: 'Run this in a terminal. Local scope keeps the token in your own config, out of any repository.',
    snippet: (url, token) =>
      `claude mcp add --transport http ${SERVER} ${url} --header "Authorization: Bearer ${token}" -s local`,
  },
  {
    key: 'cursor',
    label: 'Cursor',
    where: 'Add this to ~/.cursor/mcp.json (your user config, not the project one).',
    snippet: (url, token) =>
      JSON.stringify(
        { mcpServers: { [SERVER]: { url, headers: { Authorization: `Bearer ${token}` } } } },
        null,
        2,
      ),
  },
  {
    key: 'vscode',
    label: 'VS Code',
    where: 'Run "MCP: Open User Configuration" and add this. Not .vscode/mcp.json, which gets committed.',
    snippet: (url, token) =>
      JSON.stringify(
        { servers: { [SERVER]: { type: 'http', url, headers: { Authorization: `Bearer ${token}` } } } },
        null,
        2,
      ),
  },
  {
    key: 'codex',
    label: 'Codex',
    where: 'Add this to ~/.codex/config.toml.',
    snippet: (url, token) =>
      `[mcp_servers.${SERVER}]\nurl = "${url}"\nhttp_headers = { Authorization = "Bearer ${token}" }`,
  },
  {
    key: 'other',
    label: 'Other',
    where:
      'Any client that speaks MCP over Streamable HTTP and can send a header. Connectors that only sign in with OAuth, like claude.ai, can’t use it.',
    snippet: (url, token) => `URL:    ${url}\nHeader: Authorization: Bearer ${token}`,
  },
]

// One half of a token's name@device, as the server accepts it (AdminToken::NAME_FORMAT): lowercase, spaces become
// dashes, anything else is dropped as it is typed.
export function tokenNamePart(value: string) {
  return value
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9._-]/g, '')
    .replace(/^[._-]+/, '')
    .slice(0, 30)
}

// A first guess at the device half from the browser, so most people only check it.
export function guessDevice() {
  const nav = navigator as Navigator & { userAgentData?: { platform?: string } }
  const platform = (nav.userAgentData?.platform || navigator.platform || '').toLowerCase()
  if (platform.includes('mac')) return 'mac'
  if (platform.includes('win')) return 'windows'
  if (platform.includes('linux') || platform.includes('x11')) return 'linux'
  return 'laptop'
}
