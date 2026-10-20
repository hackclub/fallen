# Be sure to restart your server when you modify this file.
# See https://guides.rubyonrails.org/security.html#content-security-policy-header

# Report-only until the Sentry reports come back clean; then delete the last line to enforce it.
Rails.application.configure do
  # Uploads are served through the app (rails_storage_proxy); the R2 endpoint is here in case that ever becomes a redirect.
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
                   "https://cachet.hackclub.com", "https://*.slack-edge.com", # avatars: Cachet redirects to Slack's CDN
                   "https://secure.gravatar.com", # ...or to Gravatar for users without a Slack photo
                   "https://lookout.hackclub.com", "https://lookout.hackclub-assets.com", # Lookout thumbnails redirect to its asset host
                   "https://public.lapse-hackclub.link", # Lapse thumbnails
                   "https://i.ytimg.com", *r2_host
    policy.frame_src "https://www.youtube-nocookie.com"
    policy.connect_src :self, "https://cloudflareinsights.com", *("https://#{sentry.host}" if sentry), *([ "ws://#{vite}", "http://#{vite}" ] if vite)
    policy.report_uri "https://#{sentry.host}/api#{sentry.path}/security/?sentry_key=#{sentry.user}" if sentry
  end

  config.content_security_policy_report_only = true
end
