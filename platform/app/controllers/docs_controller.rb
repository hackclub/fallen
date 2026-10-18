class DocsController < ApplicationController
  allow_trial_access only: :show # Readable before signing up
  allow_unauthenticated_access only: :show # Readable before signing up
  skip_after_action :verify_authorized # Static page, no records
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  # The pages are app/frontend/docs/*.mdx and the tab is picked in the browser (TabbedPanel), so the server only
  # turns away a name with no file.
  def show
    return redirect_to docs_path if params[:page] && !pages.include?(params[:page])

    render inertia: "Docs/Show"
  end

  private

  def pages = Dir.glob("*.mdx", base: Rails.root.join("app/frontend/docs")).map { |file| File.basename(file, ".mdx") }
end
