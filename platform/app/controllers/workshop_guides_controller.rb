# The Tamagotchi workshop guide, shared with attendees. No account needed. Each part is one long page whose sections are
# the files in app/frontend/guides/tamagotchi (PCB, at /tamagotchi) or tamagotchi-<part> (/tamagotchi/<part>).
class WorkshopGuidesController < ApplicationController
  allow_unauthenticated_access only: %i[show guide] # Attendees follow along without an account
  allow_trial_access only: %i[show guide] # Attendees follow along without an account
  skip_after_action :verify_authorized # Static page, no records
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  PARTS = %w[cad firmware submit].freeze

  # /tamagotchi/<section> links from when the PCB part was paged land on that section.
  def show
    page = params[:page]
    return redirect_to workshop_guide_path(anchor: page) if page && PARTS.exclude?(page)

    render inertia: "WorkshopGuides/Show", props: { part: page || "pcb" }
  end

  # The parts used to live at /tamagotchi-guide/<part>.
  def guide
    redirect_to workshop_guide_path(page: params[:page].presence_in(PARTS)), status: :moved_permanently
  end
end
