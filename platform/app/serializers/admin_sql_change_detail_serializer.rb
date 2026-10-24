# frozen_string_literal: true

# Admin-only. Everything on /admin/sql_changes/:id. The preview's row fingerprints stay on the server.
class AdminSqlChangeDetailSerializer < AdminSqlChangeSerializer
  typelize token_name: :string, count: :number, columns: "string[]", key: [ :string, nullable: true ],
    rows: "{ before?: (string | null)[] | null; after?: (string | null)[] }[]"

  attributes :sql, :error, :resolved_at
  attribute(:token_name) { |change| change.admin_token.name }
  attribute(:count) { |change| change.preview["count"] }
  attribute(:columns) { |change| change.preview["columns"] }
  attribute(:key) { |change| change.preview["key"] }
  attribute(:rows) { |change| change.preview["rows"] }
  one :reviewer, resource: PersonSerializer
end
