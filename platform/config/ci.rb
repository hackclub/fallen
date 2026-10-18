require "digest"

# Run with bin/ci. GitHub Actions runs the same file (.github/workflows/ci.yml), so a green bin/ci is a green PR.

CI.run do
  step "Setup", "bin/rails db:prepare"

  step "Style: Ruby", "bin/rubocop"
  step "Style: Frontend", "npm run format:check"
  step "Types: Frontend", "npm run check"

  step "Security: Brakeman", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Security: Gem audit", "bin/bundler-audit --update"
  step "Security: npm audit", "npm audit --omit=dev"

  step "Tests: Rails", "bin/rails test"

  # Annotations, TypeScript prop types and route helpers are generated from the schema, serializers and routes.
  # They are committed, so regenerating must change nothing; otherwise someone forgot to run the generator.
  generated = %w[app/frontend/types/**/* app/frontend/routes/**/* db/schema.rb]
  fingerprint = -> { Digest::SHA256.hexdigest(Dir.glob(generated).select { |f| File.file?(f) }.sort.map { |f| f + File.read(f) }.join) }
  before = fingerprint.call
  step "Generated files: annotations", "bundle exec annotaterb models --frozen --show-migration"
  step "Generated files: TypeScript", "env TYPELIZER=1 bin/rails typelizer:generate:refresh"
  if before == fingerprint.call
    step "Generated files: current", "true"
  else
    failure "Generated files: stale", "Commit the regenerated files under app/frontend/types, app/frontend/routes and db/schema.rb."
  end
end
