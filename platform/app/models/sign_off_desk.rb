# The sign-off desk (/admin/sign-offs) lives in the private hackclub/fallen-desk repo (vendor/desk). Without it the
# page is the plain list in pages/Admin/SignOffs/Index.svelte. Tests set `available` so they run the same either way.
module SignOffDesk
  class << self
    attr_writer :available

    def available? = @available.nil? ? (@available = Rails.root.join("vendor/desk/frontend/Desk.svelte").exist?) : @available
  end
end
