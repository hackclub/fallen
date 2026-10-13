# frozen_string_literal: true

# Migrations that would lock a table (adding an index without CONCURRENTLY, backfilling in the same migration
# as the column, changing a column type, ...) are refused with a safe alternative. Read the message, do what
# it says. `safety_assured { }` is for when you have read it and the table is tiny; say so in a comment.
StrongMigrations.start_after = 20261013000000
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour
StrongMigrations.auto_analyze = true
StrongMigrations.target_version = 16
