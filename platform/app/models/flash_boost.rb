# A flash event: journals written between STARTS_AT and ENDS_AT, with their hours logged by then, earn more. Lulu's XP is multiplied by LULU_FACTOR,
# Sami's multiplier goes up by SAMI_STEP. The entry keeps the boosted multiplier (XpEntry.sync), so editing the
# journal's hours later still pays the boost. Home announces it while it runs (FlashBoostOverlay.svelte). All of it,
# the XP too, is only for people the FLAG is on for at /admin/flags.
module FlashBoost
  ZONE = "America/New_York"
  STARTS_AT = ActiveSupport::TimeZone[ZONE].local(2026, 11, 24, 19)
  # Midnight at the end of Sunday, Nov 29.
  ENDS_AT = ActiveSupport::TimeZone[ZONE].local(2026, 11, 30)
  LULU_FACTOR = 1.25
  SAMI_STEP = 0.25
  FLAG = :flash_boost

  def self.running?(at = Time.current) = at >= STARTS_AT && at < ENDS_AT

  # The multiplier for a journal `user` wrote at `written_at`, its hours logged at `logged_at`, from their own. Both
  # inside the event, so hours added after it to a journal written during it earn no boost.
  def self.multiplier(user, written_at:, logged_at: Time.current)
    base = user.xp_multiplier
    return base unless user.pet.in?(Team::BY_PET.keys) && running?(written_at) && running?(logged_at) && Flipper.enabled?(FLAG, user)

    user.pet == "sami" ? base + SAMI_STEP.to_d : base * LULU_FACTOR.to_d
  end

  # What Home's popup needs; nil when there's no boost for them. Development shows it from now until it ends, to
  # preview it, still only with the flag on.
  def self.props(user)
    return unless Time.current < ENDS_AT && Flipper.enabled?(FLAG, user)
    return unless running? || Rails.env.development?

    { starts_at: STARTS_AT.iso8601, ends_at: ENDS_AT.iso8601, lulu_factor: LULU_FACTOR, sami_step: SAMI_STEP }
  end
end
