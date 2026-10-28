# frozen_string_literal: true

# Reads another Inertia app's page from its HTML, where the page object (component, props, asset version) is JSON.
module InertiaPage
  module_function

  # The page object, or nil if the HTML isn't an Inertia page.
  def from(html)
    json = Nokogiri::HTML(html).at_css('script[data-page="app"]')&.text
    json.present? ? JSON.parse(json) : nil
  end
end
