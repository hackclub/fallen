# frozen_string_literal: true

module Mcp
  # The tool areas, one file each (user_tools.rb holds Mcp::Tools::UserTools). The suffix keeps a module like
  # Mcp::Tools::Users from shadowing the app's own constants inside it.
  module Tools
    # The tool classes an area defines, in the order they were written.
    def self.tools_in(area)
      area.constants.sort_by { |name| area.const_source_location(name)&.last.to_i }
        .map { |name| area.const_get(name) }
        .select { |const| const.is_a?(Class) && const < Mcp::Tool }
    end
  end
end
