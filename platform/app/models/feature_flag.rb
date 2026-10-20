# frozen_string_literal: true

# A Flipper feature as /admin/flags shows and changes it. Flipper stores the gates; this reads every feature in one
# query and applies a change as the smallest set of gate updates.
class FeatureFlag
  include ActiveModel::Validations

  KEY_FORMAT = /\A[a-z][a-z0-9_]{0,62}\z/

  # Registered with Flipper in config/initializers/flipper.rb; User#flipper_group? decides who is in each.
  GROUPS = {
    admins: { label: "Admins", description: "People with the admin role" },
    staff: { label: "Staff", description: "Admins and reviewers" },
    verified: { label: "Verified people", description: "Signed in with Hack Club Auth" },
    trial: { label: "Trial accounts", description: "Not signed in with Hack Club Auth yet" }
  }.freeze

  attr_reader :key, :gates

  validates :key, format: { with: KEY_FORMAT, message: "must be lowercase letters, numbers and underscores" }
  validate :key_is_new, on: :create

  def self.all
    Flipper.adapter.get_all.map { |key, values| new(key, values) }.sort_by(&:key)
  end

  def self.find!(key)
    raise ActiveRecord::RecordNotFound, "No flag #{key.inspect}" unless Flipper.exist?(key)

    new(key, Flipper.adapter.get(Flipper.feature(key)))
  end

  # Takes people off every flag turned on for them by name (PrivacyRequest). Returns how many were taken off.
  def self.forget(users)
    ids = users.map(&:public_id)
    all.sum do |flag|
      (flag.actors & ids).each { Flipper.feature(flag.key).disable_actor(Flipper::Actor.new(it)) }.size
    end
  end

  def initialize(key, values = {})
    @key = key.to_s
    @gates = Flipper::GateValues.new(values)
  end

  def create!
    validate!(:create)
    Flipper.add(key)
    self
  end

  def destroy! = Flipper.remove(key)

  def everyone? = gates.boolean
  def groups = gates.groups.map(&:to_s).sort
  def actors = gates.actors.to_a.sort
  def percentage_of_actors = gates.percentage_of_actors.to_i
  def percentage_of_time = gates.percentage_of_time.to_i

  def state
    if everyone? then :on
    elsif groups.any? || actors.any? || percentage_of_actors.positive? || percentage_of_time.positive? || gates.expression
      :conditional
    else :off
    end
  end

  # Who has it, in words: "on for admins, 3 people and 25% of people".
  def summary
    return "on for everyone" if everyone?

    parts = groups.map { GROUPS.dig(it.to_sym, :label)&.downcase || it }
    parts << ActionController::Base.helpers.pluralize(actors.size, "person", plural: "people") if actors.any?
    parts << "#{percentage_of_actors}% of people" if percentage_of_actors.positive?
    parts << "#{percentage_of_time}% of checks" if percentage_of_time.positive?
    parts << "an expression" if gates.expression
    parts.any? ? "on for #{parts.to_sentence}" : "off"
  end

  # Keys left out stay as they are. Actors are user public_ids. Turning it on or off for everyone clears every other
  # rule, as Flipper does, so a change to `everyone` ignores the rest.
  def update!(everyone: everyone?, groups: self.groups, actors: self.actors,
              percentage_of_actors: self.percentage_of_actors, percentage_of_time: self.percentage_of_time)
    feature = Flipper.feature(key)

    if everyone != everyone?
      everyone ? feature.enable : feature.disable
      return reload
    end

    groups = groups.map(&:to_s) & GROUPS.keys.map(&:to_s)
    actors = User.where_public_ids(actors).map(&:public_id) | (actors & self.actors)
    (groups - self.groups).each { feature.enable_group(it) }
    (self.groups - groups).each { feature.disable_group(it) }
    (actors - self.actors).each { feature.enable_actor(Flipper::Actor.new(it)) }
    (self.actors - actors).each { feature.disable_actor(Flipper::Actor.new(it)) }
    set_percentage(feature, :actors, percentage_of_actors, self.percentage_of_actors)
    set_percentage(feature, :time, percentage_of_time, self.percentage_of_time)
    reload
  end

  private

  def reload
    @gates = Flipper::GateValues.new(Flipper.adapter.get(Flipper.feature(key)))
    self
  end

  def set_percentage(feature, kind, value, current)
    value = value.to_i.clamp(0, 100)
    return if value == current

    value.zero? ? feature.public_send(:"disable_percentage_of_#{kind}") : feature.public_send(:"enable_percentage_of_#{kind}", value)
  end

  def key_is_new
    errors.add(:key, "is already a flag") if Flipper.exist?(key)
  end
end
