# The Tamagotchi workshop guide (app/frontend/guides/tamagotchi, one page per file), shared with attendees. No account needed.
class WorkshopGuidesController < ApplicationController
  allow_unauthenticated_access only: %i[show guide] # Attendees follow along without an account
  allow_trial_access only: %i[show guide] # Attendees follow along without an account
  skip_after_action :verify_authorized # Static page, no records
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  FIRST_PAGE = "overview"

  # The page is picked in the browser from the file name; the server only turns away a name with no file.
  def show
    page = params[:page] || FIRST_PAGE
    return redirect_to workshop_guide_path unless pages.include?(page)

    render inertia: "WorkshopGuides/Show", props: { page: }
  end

  # The same build as one first-person walkthrough (app/frontend/guides/tamagotchi-guide.mdx).
  def guide
    render inertia: "WorkshopGuides/Guide"
  end

  private

  def pages = Dir.glob("*.mdx", base: Rails.root.join("app/frontend/guides/tamagotchi")).map { |file| File.basename(file, ".mdx") }
end
