# frozen_string_literal: true

module Mcp
  # The shapes a tool hands a language model. A model reads every byte into a context window it shares with the rest
  # of its work, so rows are short, text is clipped and avatars and picture URLs are left out.
  module Compact
    TEXT = 300
    PER_PAGE = 25
    MAX_PER_PAGE = 50

    module_function

    # A string cut to `max` characters with a marker saying how much was cut.
    def clip(text, max = TEXT)
      return text unless text.is_a?(String) && text.length > max

      "#{text[0, max]}… [+#{text.length - max} chars]"
    end

    def person(user) = user && { id: user.public_id, name: user.display_name, slackId: user.slack_id }

    def time(value) = value&.iso8601

    # One page of a relation as `{ rows, page, pages, total }`.
    def paginate(relation, page: nil, per: nil)
      per = (per || PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)
      page = [ page.to_i, 1 ].max
      total = relation.count
      records = relation.limit(per).offset((page - 1) * per).to_a
      rows = block_given? ? yield(records) : records
      { rows:, page:, pages: (total / per.to_f).ceil, total: }
    end

    # The JSON Schema for the `page` and `per` arguments every list tool takes.
    def page_arguments
      { page: { type: "integer", minimum: 1 }, per: { type: "integer", minimum: 1, maximum: MAX_PER_PAGE } }
    end
  end
end
