# frozen_string_literal: true

# GitHub's public REST API, without a token (60 requests an hour per address). Only for repositories on github.com.
module Github
  HOST = "https://api.github.com"
  REPO = %r{\Ahttps://github\.com/([\w.-]+)/([\w.-]+?)(?:\.git)?/?\z}

  module_function

  # When the first and the last commit up to `sha` were made, or nil when the repository isn't on GitHub or GitHub
  # doesn't answer. Two requests: the newest commit, then the last page of one commit each, which is the oldest.
  def commit_range(repo_url, sha)
    owner, name = repo_url.to_s.match(REPO)&.captures
    return unless owner && sha.present?

    newest = connection.get("/repos/#{owner}/#{name}/commits", sha:, per_page: 1)
    return unless newest.success?

    last_page = newest.headers["link"].to_s[/[?&]page=(\d+)>; rel="last"/, 1]
    oldest = last_page ? connection.get("/repos/#{owner}/#{name}/commits", sha:, per_page: 1, page: last_page) : newest
    return unless oldest.success?

    [ oldest, newest ].map { Time.iso8601(JSON.parse(it.body).first.dig("commit", "committer", "date")) }
  rescue Faraday::Error, JSON::ParserError, ArgumentError, NoMethodError
    nil
  end

  def connection
    Faraday.new(url: HOST, headers: { "Accept" => "application/vnd.github+json", "User-Agent" => "fallen" }) do |f|
      f.options.open_timeout = 5
      f.options.timeout = 10
    end
  end
end
