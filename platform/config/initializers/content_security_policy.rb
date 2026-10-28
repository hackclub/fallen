# Be sure to restart your server when you modify this file.
# See https://guides.rubyonrails.org/security.html#content-security-policy-header

# Report-only until the Sentry reports come back clean; then delete the last line to enforce it.
Rails.application.configure do
  # Uploads are PUT straight to R2 and served through the app (rails_storage_proxy), except Markdown images, which redirect.
  r2_host = ENV["R2_ENDPOINT"].presence && URI(ENV["R2_ENDPOINT"]).then { |uri| "#{uri.scheme}://#{uri.host}" }
  # Browser errors and CSP reports go to the frontend Sentry project.
  sentry = ENV["SENTRY_FRONTEND_DSN"].presence && URI(ENV["SENTRY_FRONTEND_DSN"])
  vite = "#{ViteRuby.config.host}:#{ViteRuby.config.port}" if Rails.env.development?

  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none
    policy.frame_ancestors :self
    # Cloudflare injects its Web Analytics beacon into every page it proxies.
    policy.script_src :self, "https://static.cloudflareinsights.com", *([ :unsafe_eval, "http://#{vite}" ] if vite)
    # Svelte's style: directives and SSR output write inline style attributes.
    policy.style_src :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src :self, :data, "https://fonts.gstatic.com"
    policy.img_src :self, :data, :blob,
                   "https://cachet.hackclub.com", "https://*.slack-edge.com", # avatars: Cachet redirects to Slack's CDN,
                   "https://l4-bucket.dunkirk.sh", # ...its own copy,
                   "https://secure.gravatar.com", "https://i0.wp.com", "https://i1.wp.com", "https://i2.wp.com", # ...or Gravatar, whose fallback image comes through wp.com
                   "https://lookout.hackclub.com", "https://lookout.hackclub-assets.com", # Lookout thumbnails redirect to its asset host
                   "https://public.lapse-hackclub.link", # Lapse thumbnails
                   "https://stardance.hackclub.com", "https://fabricate.hackclub-assets.com", # photos in transferred journals (ProjectTransfer)
                   "https://fallout.hackclub.com", "https://cdn.hackclub.com", "https://user-cdn.hackclub-assets.com", # ...where Hack Club's CDN redirects to its asset host
                   "https://i.ytimg.com", *r2_host
    policy.frame_src "https://www.youtube-nocookie.com"
    # The landing page asks Hack Club Auth whether the person is already signed in there.
    policy.connect_src :self, "https://auth.hackclub.com", "https://cloudflareinsights.com", *r2_host, *("https://#{sentry.host}" if sentry), *([ "ws://#{vite}", "http://#{vite}" ] if vite)
    policy.report_uri "https://#{sentry.host}/api#{sentry.path}/security/?sentry_key=#{sentry.user}" if sentry
  end

  # Cloudflare's bot check injects an inline script into every page and takes the nonce from this header.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  config.content_security_policy_report_only = true
end
