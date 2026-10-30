// Keeps the user bot in a huddle in SLACK_HUDDLE_CHANNEL_ID around the clock.
//
// Huddles have no public API. This signs in with the account's browser session (SLACK_BROWSER_TOKEN, an xoxc-
// token, and SLACK_BROWSER_COOKIE, its `d` cookie), joins the channel's huddle the way the desktop client does
// (`rooms.join`, which also starts one when none is running) and then connects to the Amazon Chime meeting
// behind it, because Slack only lists someone as a participant once their audio is connected. It sends no sound.
// When the huddle ends (Slack stops every huddle after 24 hours) or the connection drops, it joins again. A huddle
// that has run for RESTART_ALONE_AFTER with nobody else in it is left so a fresh one starts, which puts Slack's
// 24 hour cut at a quiet time instead of in the middle of someone's session.
// Slack lets a huddle take 250 joins, rejoins included. Once the main one is full, HuddleSyncJob lists the team
// channels in tmp/huddle_overflow and this keeps a huddle open in each of them too, until it is no longer listed
// and nobody else is in it.
// The method shapes follow https://github.com/ingoau/huddlefm; the Chime protocol is chime/SignalingProtocol.proto.
//
// bin/worker and bin/dev start this; it idles quietly when the variables are missing.
import { readFileSync } from 'node:fs'
import protobuf from 'protobufjs'
import nodeDataChannel from 'node-datachannel'

for (const file of ['.env', '.env.development']) {
  try {
    process.loadEnvFile(file)
  } catch {
    // optional
  }
}

const token = process.env.SLACK_BROWSER_TOKEN
const cookie = process.env.SLACK_BROWSER_COOKIE
const channel = process.env.SLACK_HUDDLE_CHANNEL_ID
// Where Slack's media servers host the huddle. Nothing is streamed, so it hardly matters.
const region = process.env.SLACK_HUDDLE_REGION || 'us-east-1'
const log = (event, fields = {}) => console.log(JSON.stringify({ event: `huddle.${event}`, ...fields }))

// --- Slack ---------------------------------------------------------------------------------------------------

async function slack(method, fields) {
  const response = await fetch(`https://slack.com/api/${method}`, {
    method: 'POST',
    headers: { cookie: `d=${cookie}` },
    body: new URLSearchParams({ token, ...fields }),
    signal: AbortSignal.timeout(30_000),
  })
  if (!response.ok) throw new Error(`${method} HTTP ${response.status}`)
  const body = await response.json()
  if (!body.ok) throw new Error(`${method} failed: ${body.error ?? 'unknown_error'}`)
  return body
}

async function joinRoom(channel) {
  const body = await slack('rooms.join', { channel_id: channel, regions: region, multidevice: 'true' })
  return { callId: body.call.call_id, ...body.call.free_willy }
}

// The huddle as Slack sees it: null when it is gone, otherwise who is in it and how long it has run.
async function roomState(callId) {
  const body = await slack('screenhero.rooms.info', {
    room: callId,
    _x_reason: 'all-calls-store/conditional-fetch',
  })
  const room = body.room
  if (room.has_ended || Number(room.date_end) > 0) return null
  return {
    participants: (room.participants ?? []).map((p) => (typeof p === 'string' ? p : p?.user_id)),
    ageMs: Number(room.date_start) > 0 ? Date.now() - Number(room.date_start) * 1000 : 0,
  }
}

// --- Chime signaling -----------------------------------------------------------------------------------------

const Frame = protobuf
  .parse(readFileSync(new URL('./chime/SignalingProtocol.proto', import.meta.url), 'utf8'), {
    keepCase: true,
  })
  .root.lookupType('SdkSignalFrame')
const frameTypes = Frame.lookupEnum('Type').values
// Audio status codes Chime sends when the attendee is done for good, so a reconnect would be refused.
const finalAudioStatus = {
  301: 'joined from another device',
  302: 'audio disconnected',
  403: 'rejected',
  410: 'meeting ended',
  411: 'removed',
}

function encodeFrame(type, body = {}) {
  const encoded = Frame.encode(
    Frame.fromObject({ timestamp_ms: Date.now(), type: frameTypes[type], ...body }),
  ).finish()
  // One type byte, then the protobuf.
  const out = new Uint8Array(encoded.length + 1)
  out[0] = 0x05
  out.set(encoded, 1)
  return out
}

function decodeFrame(data) {
  return Frame.toObject(Frame.decode(new Uint8Array(data).subarray(1)), {
    enums: String,
    longs: Number,
    bytes: String,
  })
}

// One signaling socket. `frames` receives every decoded frame; `wait` resolves with the next frame of a type.
function openSignaling(meeting, attendee, onEnd) {
  const url = `${meeting.MediaPlacement.SignalingUrl}?X-Chime-Control-Protocol-Version=3&X-Amzn-Chime-Send-Close-On-Error=1`
  const socket = new WebSocket(url, ['_aws_wt_session', attendee.JoinToken])
  socket.binaryType = 'arraybuffer'
  const listeners = new Set()
  let lastInbound = Date.now()
  let pingId = 0
  let pings

  const send = (type, body) => {
    if (socket.readyState !== WebSocket.OPEN) return false
    socket.send(encodeFrame(type, body))
    return true
  }
  socket.onmessage = (message) => {
    lastInbound = Date.now()
    let frame
    try {
      frame = decodeFrame(message.data)
    } catch {
      return // newer frame types this proto does not know
    }
    if (frame.type === 'PING_PONG' && frame.ping_pong?.type === 'PING') {
      send('PING_PONG', { ping_pong: { type: 2, ping_id: frame.ping_pong.ping_id } })
    }
    // Who Chime has in the audio, muted or dropped. Logged only for now, to learn whether external_user_id maps to
    // Slack ids before mute time is tracked from it.
    if (frame.type === 'AUDIO_STREAM_ID_INFO')
      log('chime_streams', { streams: frame.audio_stream_id_info?.streams })
    const status = frame.audio_status?.audio_status
    if (status !== undefined && status !== 200)
      onEnd(`audio status ${status} (${finalAudioStatus[status] ?? 'lost'})`, status in finalAudioStatus)
    for (const listener of listeners) listener(frame)
  }
  socket.onclose = (event) => {
    clearInterval(pings)
    onEnd(`signaling closed ${event.code} ${event.reason}`.trim(), event.code === 4410)
  }
  const opened = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('timed out opening Chime signaling')), 10_000)
    socket.onopen = () => {
      clearTimeout(timer)
      resolve()
    }
    socket.onerror = () => {
      clearTimeout(timer)
      reject(new Error('Chime signaling connection failed'))
    }
  })

  return {
    opened,
    send,
    get silentFor() {
      return Date.now() - lastInbound
    },
    wait(type, timeout = 15_000) {
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
          listeners.delete(listener)
          reject(new Error(`timed out waiting for Chime ${type}`))
        }, timeout)
        const listener = (frame) => {
          if (frame.type !== type && !(frame.error && frame.type !== 'PING_PONG')) return
          clearTimeout(timer)
          listeners.delete(listener)
          if (frame.type === type) resolve(frame)
          else
            reject(
              new Error(`Chime ${frame.type} error ${frame.error.status}: ${frame.error.description ?? ''}`),
            )
        }
        listeners.add(listener)
      })
    },
    startPings() {
      pings = setInterval(() => send('PING_PONG', { ping_pong: { type: 1, ping_id: ++pingId } }), 10_000)
    },
    close() {
      clearInterval(pings)
      socket.onclose = null
      try {
        socket.close()
      } catch {
        // already gone
      }
    },
  }
}

// --- Chime media ---------------------------------------------------------------------------------------------

function iceServers(turn) {
  return (turn.uris ?? []).flatMap((uri) => {
    const match = uri.match(/^(turns?):([^:?]+):(\d+)(?:\?transport=(\w+))?/)
    if (!match) return []
    const [, scheme, hostname, port, transport] = match
    const relayType = scheme === 'turns' ? 'TurnTls' : transport === 'tcp' ? 'TurnTcp' : 'TurnUdp'
    return [{ hostname, port: Number(port), username: turn.username, password: turn.password, relayType }]
  })
}

// An RTCP sender report with nothing sent, so the audio host sees the stream alive.
function senderReport(ssrc) {
  const packet = Buffer.alloc(28)
  packet[0] = 0x80
  packet[1] = 200
  packet.writeUInt16BE(6, 2)
  packet.writeUInt32BE(ssrc, 4)
  const ntp = Date.now() / 1000 + 2_208_988_800
  packet.writeUInt32BE(Math.floor(ntp) >>> 0, 8)
  packet.writeUInt32BE(Math.floor((ntp % 1) * 2 ** 32) >>> 0, 12)
  return packet
}

// Connects one attendee to the meeting: JOIN on signaling, a relay-only WebRTC peer with a silent audio track
// and the inactive video line Chime insists on, SUBSCRIBE with the offer, then the answer. Resolves once media
// is connected and Slack can see the participant; `onEnd(reason, final)` fires when the connection is over.
async function connectMedia({ meeting, attendee }, onEnd) {
  const { PeerConnection, Audio, Video } = nodeDataChannel
  let ended = false
  let peer
  let reports
  const signaling = openSignaling(meeting, attendee, (reason, final) => end(reason, final))
  const end = (reason, final = false) => {
    if (ended) return
    ended = true
    clearInterval(reports)
    signaling.close()
    try {
      peer?.close()
    } catch {
      // already closed
    }
    onEnd(reason, final)
  }

  try {
    await signaling.opened
    signaling.send('JOIN', {
      join: {
        protocol_version: 2,
        flags: 2, // HAS_STREAM_UPDATE: attendee presence
        client_details: {
          app_name: 'Fallen',
          app_version: '1',
          device_model: process.platform,
          device_make: process.arch,
          platform_name: 'Node',
          platform_version: process.version,
          client_source: 'amazon-chime-sdk-js',
          chime_sdk_version: '3.31.0',
        },
        audio_session_id: Math.floor(Math.random() * 2 ** 32),
        wants_compressed_sdp: false,
      },
    })
    const turn = (await signaling.wait('JOIN_ACK')).joinack?.turn_credentials
    if (!turn?.uris?.length) throw new Error('Chime JOIN_ACK carried no TURN servers')
    await signaling.wait('INDEX', 5_000).catch(() => undefined)

    peer = new PeerConnection('huddle', { iceServers: iceServers(turn), iceTransportPolicy: 'relay' })
    const ssrc = (Math.random() * 2 ** 31) >>> 0
    const audio = new Audio('0', 'SendRecv')
    audio.addOpusCodec(111, 'minptime=10;useinbandfec=1')
    audio.addSSRC(ssrc, 'fallen', 'fallen', 'audio')
    const video = new Video('1', 'Inactive')
    video.addH264Codec(102, 'level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f')
    const audioTrack = peer.addTrack(audio)
    peer.addTrack(video)
    peer.onStateChange((state) => (state === 'failed' || state === 'closed') && end(`peer ${state}`))
    peer.onIceStateChange((state) => (state === 'failed' || state === 'closed') && end(`ICE ${state}`))

    const gathered = new Promise((resolve) =>
      peer.onGatheringStateChange((state) => state === 'complete' && resolve()),
    )
    const connected = new Promise((resolve) => {
      audioTrack.onOpen(resolve)
      peer.onStateChange((state) => state === 'connected' && resolve())
    })
    peer.setLocalDescription()
    await Promise.race([gathered, sleep(10_000)]) // Chime takes the whole offer at once, no trickle
    const offer = peer.localDescription().sdp
    if (!/typ relay/.test(offer)) throw new Error('no TURN relay candidate; Chime media is unreachable')

    signaling.send('SUBSCRIBE', {
      sub: {
        duplex: 1, // RX: nothing to send
        send_streams: [
          {
            media_type: 1,
            track_label: 'AmazonChimeExpressAudio',
            stream_id: 1,
            group_id: 1,
            framerate: 15,
            max_bitrate_kbps: 600,
            avg_bitrate_bps: 400_000,
            attendee_id: attendee.AttendeeId,
          },
        ],
        receive_stream_ids: [0],
        sdp_offer: offer.replace(/^o=\S+/m, 'o=mozilla-chrome'), // how the JS SDK marks a unified-plan offer
        audio_host: meeting.MediaPlacement.AudioHostUrl,
        audio_checkin: false,
        audio_muted: false,
      },
    })
    const answer = (await signaling.wait('SUBSCRIBE_ACK')).suback?.sdp_answer
    if (!answer) throw new Error('Chime refused SUBSCRIBE')
    peer.setRemoteDescription(
      answer
        .split('\r\n')
        .filter((line) => !/typ srflx/.test(line))
        .join('\r\n'),
      'answer',
    )
    await Promise.race([
      connected,
      sleep(15_000).then(() => Promise.reject(new Error('Chime media did not connect within 15s'))),
    ])

    signaling.startPings()
    reports = setInterval(() => {
      if (signaling.silentFor > 15_000) return end('no signaling for 15s')
      try {
        audioTrack.sendMessageBinary(senderReport(ssrc))
      } catch {
        // the watchdog above notices a dead connection
      }
    }, 1_000)
    return { leave: () => (signaling.send('LEAVE', { leave: {} }), end('left')) }
  } catch (error) {
    end(error.message)
    throw error
  }
}

// --- Keep going ----------------------------------------------------------------------------------------------

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
const CHECK_EVERY = 5 * 60_000
const MAX_BACKOFF = 60_000
const REMOVED_PAUSE = 5 * 60_000
const RESTART_ALONE_AFTER = 12 * 60 * 60_000
const OVERFLOW_FILE = new URL('../tmp/huddle_overflow', import.meta.url)
const OVERFLOW_CHECK_EVERY = 15_000

// How to leave each huddle the account is in, by channel, so stopping leaves all of them.
const leaves = new Map()

// Keeps the account in the channel's huddle for as long as `wanted()` says, or around the clock.
async function keepInHuddle(userId, channel, wanted = () => true) {
  let failures = 0

  while (wanted()) {
    let wait = Math.min(MAX_BACKOFF, 1_000 * 2 ** failures)
    try {
      const room = await joinRoom(channel)
      const over = Promise.withResolvers()
      const media = await connectMedia(room, (reason, final) => over.resolve({ reason, final }))
      leaves.set(channel, media.leave)
      failures = 0
      log('joined', { call_id: room.callId, channel })

      // A connection that quietly stopped counting is caught by asking Slack now and then.
      const checks = setInterval(async () => {
        const state = await roomState(room.callId).catch(() => undefined)
        if (state === undefined) return
        if (state === null) over.resolve({ reason: 'huddle ended', final: true })
        else if (!state.participants.includes(userId))
          over.resolve({ reason: 'not listed as a participant', final: false })
        else if (state.participants.length === 1 && !wanted())
          over.resolve({ reason: 'no longer needed', final: true })
        else if (state.participants.length === 1 && state.ageMs > RESTART_ALONE_AFTER)
          over.resolve({ reason: 'restarting a quiet huddle', final: true, restart: true })
      }, CHECK_EVERY)
      const { reason, final, restart } = await over.promise
      clearInterval(checks)
      leaves.delete(channel)
      media.leave()
      log('left', { call_id: room.callId, channel, reason })
      // Slack ends a huddle once its last person leaves; joining before then would land back in the old one.
      if (restart) await waitForEnd(room.callId)
      wait = reason.includes('removed') ? REMOVED_PAUSE : final ? 2_000 : 1_000
    } catch (error) {
      failures += 1
      log('failed', { channel, error: error.message, retry_in_ms: wait })
    }
    await sleep(wait)
  }
}

function overflowChannels() {
  try {
    return new Set(readFileSync(OVERFLOW_FILE, 'utf8').split('\n').filter(Boolean))
  } catch {
    return new Set()
  }
}

// Opens a huddle in each team channel HuddleSyncJob lists, and lets it go once it is no longer listed.
async function keepOverflowHuddles(userId) {
  const running = new Set()
  let listed = new Set()
  for (;;) {
    listed = overflowChannels()
    for (const channel of listed) {
      if (running.has(channel)) continue
      running.add(channel)
      keepInHuddle(userId, channel, () => listed.has(channel)).finally(() => running.delete(channel))
    }
    await sleep(OVERFLOW_CHECK_EVERY)
  }
}

async function main() {
  const stop = () => {
    log('stopping')
    for (const leave of leaves.values()) leave()
    process.exit(0)
  }
  process.on('SIGTERM', stop)
  process.on('SIGINT', stop)

  const userId = (await slack('auth.test')).user_id
  await Promise.all([keepInHuddle(userId, channel), keepOverflowHuddles(userId)])
}

async function waitForEnd(callId) {
  for (let i = 0; i < 12; i++) {
    await sleep(5_000)
    if ((await roomState(callId).catch(() => undefined)) === null) return
  }
  log('still_running', { call_id: callId })
}

if (!token || !cookie || !channel) {
  console.log('[huddle] SLACK_BROWSER_TOKEN, SLACK_BROWSER_COOKIE or SLACK_HUDDLE_CHANNEL_ID not set - idle.')
  setInterval(() => {}, 1 << 30)
} else {
  await main()
}
