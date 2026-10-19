# frozen_string_literal: true

# Remembers which trial account (User#trial?) this browser made, so coming back with the same email picks it back up.
module TrialCookie
  extend ActiveSupport::Concern

  COOKIE = :trial_user_id

  private

  def remembered_trial(email) = User.kept.trial.find_by(id: cookies.encrypted[COOKIE], email: email)

  def remember_trial(user)
    cookies.encrypted[COOKIE] = { value: user.id, expires: 1.year, httponly: true, secure: Rails.env.production?, same_site: :lax }
  end

  def forget_trial = cookies.delete(COOKIE)
end
