import { svelte } from '@sveltejs/vite-plugin-svelte'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import { fileURLToPath } from 'node:url'

// Vite only allows localhost origins to load modules by default. When the dev server is exposed on another
// host (VITE_RUBY_HOST, e.g. a Tailscale IP), the Rails page served from that host needs to be allowed too.
// `tailscale serve` can also route /vite-dev straight to Vite on the machine's .ts.net name, so allow those.
const escapeRegExp = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
const devHost = process.env.VITE_RUBY_HOST
const allowedOrigins = [
  /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/,
  ...(devHost ? [new RegExp(`^https?://${escapeRegExp(devHost)}(:\\d+)?$`)] : []),
]

export default defineConfig({
  plugins: [svelte(), tailwindcss(), RubyPlugin()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./app/frontend', import.meta.url)),
    },
  },
  server: {
    cors: { origin: allowedOrigins },
    allowedHosts: ['.ts.net', ...(devHost ? [devHost] : [])],
  },
})
