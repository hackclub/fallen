ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Tests never run the frontend, so the layouts' Vite tags render nothing rather than needing a build to look up.
ViteRails::TagHelpers.prepend(Module.new do
  %i[vite_client_tag vite_javascript_tag vite_typescript_tag vite_stylesheet_tag].each { |name| define_method(name) { |*, **| nil } }
end)

module ActiveSupport
  class TestCase
    # A few workers is as fast as one per core for a suite this size, and each is a whole Rails process with its own
    # database. PARALLEL_WORKERS overrides.
    parallelize(workers: [ Etc.nprocessors, 4 ].min)
    fixtures :all

    # Bullet raises on N+1 queries and unused preloads (config/environments/test.rb). Fix the query, don't
    # silence the check: `includes`/`preload` the association, or precompute aggregates in one grouped query.
    setup { Bullet.start_request }
    teardown do
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
    end

    # Fails when the block runs more than `limit` SQL statements (schema and transaction statements excluded).
    # Budgets catch pages that load a little more on every change until they are slow.
    def assert_query_budget(limit, &block)
      queries = []
      counter = ->(_name, _start, _finish, _id, payload) {
        next if payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:cached]

        queries << payload[:sql]
      }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      assert queries.size <= limit, "Expected at most #{limit} queries, ran #{queries.size}:\n#{queries.join("\n")}"
    end

    # Temporarily replace a singleton/module method: stub_method(HCA, :identity, { "id" => "x" }) { ... }
    def stub_method(target, name, value)
      original = target.method(name)
      target.define_singleton_method(name) { |*_args, **_kwargs| value }
      yield
    ensure
      target.define_singleton_method(name, original)
    end

    def with_env(values)
      previous = values.keys.to_h { |k| [ k, ENV[k] ] }
      values.each { |k, v| ENV[k] = v }
      yield
    ensure
      previous.each { |k, v| ENV[k] = v }
    end
  end
end

module FixtureHelper
  # A photo for a journal, since every one needs at least one for its hours (Journal::MINUTES_PER_IMAGE).
  # Enough writing for a journal (Journal::MIN_BODY_LENGTH), starting with `start`.
  def journal_text(start = "Worked on it") = "#{start}. #{'Wrote down what I did and what I learned along the way. ' * 2}".strip

  def photo(name = "photo.png") = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("png"), filename: name, content_type: "image/png")

  # Adds `count` journals without hours to a project, newer than the fixtures, so pagination has something to do.
  def pad_journals(project, count)
    now = Time.current
    Journal.insert_all(Array.new(count) { |i| { project_id: project.id, user_id: project.user_id, body: "Journal #{i}", source: "web", created_at: now + i, updated_at: now + i } })
  end
end

module SignInHelper
  # Uses the local-only DevController route to establish a session.
  def sign_in_as(user)
    get dev_sign_in_as_path(user.id)
    assert_redirected_to home_path
  end
end

module InertiaHelper
  # The page's props as the Inertia client receives them.
  def inertia_props(path, component)
    get path, headers: { "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version.to_s }
    assert_response :success
    assert_equal component, response.parsed_body["component"]
    response.parsed_body["props"]
  end

  # The follow-up request Inertia's client makes for deferred props (InertiaRails.defer).
  def load_deferred(path, component, *props)
    get path, headers: {
      "X-Inertia" => "true",
      "X-Inertia-Version" => InertiaRails.configuration.version.to_s,
      "X-Inertia-Partial-Component" => component,
      "X-Inertia-Partial-Data" => props.join(",")
    }
    assert_response :success
    response.parsed_body["props"]
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
  include InertiaHelper
end

# Stands in for Slack::Web::Client. Records every call; chat_postMessage answers with a fresh ts.
class FakeSlackClient
  attr_reader :calls

  def initialize
    @calls = []
    @counter = 0
  end

  def method_missing(name, *args, **kwargs)
    @calls << [ name, args.first || kwargs ]
    Slack::Messages::Message.new(name == :chat_postMessage ? { "ok" => true, "ts" => "1700009999.#{(@counter += 1).to_s.rjust(6, '0')}" } : { "ok" => true, "messages" => [] })
  end

  def respond_to_missing?(*) = true

  def calls_to(name) = calls.select { |n, _| n == name }.map(&:last)
end

# Stands in for SlackBot::BrowserClient. Answers each method from `responses` (a value or a block taking the
# fields); a value that is an exception is raised.
class FakeBrowserClient
  attr_reader :calls

  def initialize(responses = {})
    @responses = responses
    @calls = []
  end

  def call(method, **fields)
    @calls << [ method, fields ]
    response = @responses.fetch(method) { raise SlackBot::BrowserClient::Error.new(method, "unexpected_call") }
    response = response.call(fields) if response.respond_to?(:call)
    raise response if response.is_a?(Exception)

    response
  end
end

module SlackStubHelper
  # Routes SlackBot.client (and user-token clients) to a FakeSlackClient for the block. response_url posts
  # (Faraday.post) are recorded on the fake as :response_url calls.
  def with_fake_slack(journals_channel: "CJOURNALS")
    fake = FakeSlackClient.new
    SlackBot.instance_variable_set(:@client, fake)
    original_client_for = SlackMessaging.method(:client_for)
    original_post = Faraday.method(:post)
    SlackMessaging.define_singleton_method(:client_for) { |_user| fake }
    Faraday.define_singleton_method(:post) { |url, body = nil, *_rest| fake.calls << [ :response_url, { url: url, body: body && JSON.parse(body) } ] }
    with_env("SLACK_BOT_TOKEN" => "xoxb-test", "SLACK_SIGNING_SECRET" => "secret", "SLACK_JOURNALS_CHANNEL_ID" => journals_channel) { yield fake }
  ensure
    SlackMessaging.define_singleton_method(:client_for, original_client_for)
    Faraday.define_singleton_method(:post, original_post)
    SlackBot.reset_client!
  end
end

class ActiveSupport::TestCase
  include SlackStubHelper
  include FixtureHelper
end
