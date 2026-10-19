module ApplicationHelper
  # Preload links for the Inertia page's own chunks (the page component and what only it imports), so the browser
  # asks for them along with the HTML instead of after the entry script has run and read the page name: one round
  # trip fewer on every first load. Thruster turns the Link header into 103 Early Hints. Nothing when the Vite dev
  # server is serving the modules.
  def inertia_page_preload_tags
    page = @_inertia_page
    return if page.nil? || vite_manifest.dev_server_running?

    chunks = vite_manifest.resolve_entries("pages/#{page[:component]}.svelte")
    entry = vite_manifest.resolve_entries("inertia", type: :typescript)
    scripts = chunks[:scripts] + chunks[:imports] - entry[:scripts] - entry[:imports]
    styles = chunks[:stylesheets] - entry[:stylesheets]

    links = scripts.map { |src| "<#{src}>; rel=modulepreload; as=script; crossorigin" } + styles.map { |href| "<#{href}>; rel=preload; as=style" }
    response.headers["link"] = [ response.headers["link"], *links ].compact.join(",") if links.any?

    safe_join(scripts.map { |src| tag.link(rel: "modulepreload", href: src, crossorigin: "anonymous") } +
      styles.map { |href| tag.link(rel: "preload", as: "style", href: href) })
  rescue ViteRuby::MissingEntrypointError
    nil
  end
end
