# frozen_string_literal: true

module SlackBot
  # Read-only dot-access wrapper around Slack's JSON. Unknown keys return nil instead of raising,
  # so `payload.event.thread_ts` is safe even when the key is absent.
  class Payload
    def self.wrap(value)
      case value
      when Payload then value
      when Hash then new(value)
      when Array then value.map { |v| wrap(v) }
      else value
      end
    end

    def initialize(hash)
      @hash = hash.to_h.transform_keys(&:to_s).freeze
    end

    def [](key) = self.class.wrap(@hash[key.to_s])
    def dig(*keys) = self.class.wrap(@hash.dig(*keys.map(&:to_s)))
    def key?(key) = @hash.key?(key.to_s)
    def fetch(key, *default) = self.class.wrap(@hash.fetch(key.to_s, *default))
    def to_h = @hash
    def to_json(*args) = @hash.to_json(*args)
    def inspect = "#<SlackBot::Payload #{@hash.inspect}>"
    def blank? = @hash.blank?
    def present? = !blank?

    def respond_to_missing?(name, include_private = false) = @hash.key?(name.to_s) || super

    def method_missing(name, *args, &block)
      return super unless args.empty? && block.nil?

      key = name.to_s
      return self[key] if @hash.key?(key)
      return nil if key.match?(/\A[a-z][a-z0-9_]*\z/)

      super
    end
  end
end
