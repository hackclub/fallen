// Local-dev bridge: receives Slack events over Socket Mode and replays them as signed HTTP requests
// against the Rails app, so the exact same SlackController / app/bot code runs locally without a tunnel.
//
//   SLACK_APP_TOKEN=xapp-...  SLACK_SIGNING_SECRET=...  node script/slack_socket_mode.mjs
//
// bin/dev starts this automatically; it idles quietly when the tokens are missing.
import { createHmac } from 'node:crypto'

for (const file of ['.env', '.env.development']) {
  try {
    process.loadEnvFile(file)
  } catch {
    // optional
  }
}

const appToken = process.env.SLACK_APP_TOKEN
const signingSecret = process.env.SLACK_SIGNING_SECRET
const target = (
  process.env.SLACK_SOCKET_FORWARD_URL || `http://localhost:${process.env.PORT || 3000}`
).replace(/\/$/, '')
const log = (...args) => console.log('[slack]', ...args)

if (!appToken || !signingSecret) {
  log('SLACK_APP_TOKEN or SLACK_SIGNING_SECRET not set - Socket Mode bridge is idle.')
  setInterval(() => {}, 1 << 30)
} else {
  const { SocketModeClient } = await import('@slack/socket-mode')
  const client = new SocketModeClient({ appToken })

  const sign = (rawBody) => {
    const timestamp = Math.floor(Date.now() / 1000).toString()
    const signature =
      'v0=' + createHmac('sha256', signingSecret).update(`v0:${timestamp}:${rawBody}`).digest('hex')
    return { 'X-Slack-Request-Timestamp': timestamp, 'X-Slack-Signature': signature }
  }

  const forward = async (path, rawBody, contentType) => {
    const response = await fetch(`${target}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': contentType, ...sign(rawBody) },
      body: rawBody,
      signal: AbortSignal.timeout(2800),
    })
    const text = await response.text()
    if (!response.ok) log(`${path} -> HTTP ${response.status}`, text.slice(0, 300))
    try {
      return text ? JSON.parse(text) : undefined
    } catch {
      return undefined
    }
  }

  client.on('slack_event', async ({ type, body, ack }) => {
    try {
      if (type === 'events_api') {
        await ack()
        await forward('/slack/events', JSON.stringify(body), 'application/json')
      } else if (type === 'slash_commands') {
        const result = await forward(
          '/slack/commands',
          new URLSearchParams(body).toString(),
          'application/x-www-form-urlencoded',
        )
        await ack(result)
      } else if (type === 'interactive') {
        const result = await forward(
          '/slack/interactions',
          new URLSearchParams({ payload: JSON.stringify(body) }).toString(),
          'application/x-www-form-urlencoded',
        )
        await ack(result)
      } else {
        await ack()
      }
    } catch (error) {
      log(`failed to forward ${type}:`, error.message)
      try {
        await ack()
      } catch {
        // already acked
      }
    }
  })

  client.on('connected', () => log(`connected via Socket Mode, forwarding to ${target}`))
  client.on('disconnected', () => log('disconnected'))
  await client.start()
}
