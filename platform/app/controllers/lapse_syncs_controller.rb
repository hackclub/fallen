# The journal composer asks for a fresh copy of the person's Lapse timelapses when it opens, then reloads its
# `lapse` prop until `synced_at` moves.
class LapseSyncsController < ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Acts only on the current user
  rate_limit to: 20, within: 1.minute, only: :create, with: -> { redirect_back fallback_location: projects_path }

  def create
    SyncLapseTimelapsesJob.perform_later(current_user) if current_user.lapse_connected?
    redirect_back fallback_location: projects_path
  end
end
