ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

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

module SignInHelper
  # Uses the local-only DevController route to establish a session.
  def sign_in_as(user)
    get dev_sign_in_as_path(user.id)
    assert_redirected_to home_path
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
end
