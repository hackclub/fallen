# frozen_string_literal: true

module Mcp
  # Raw SQL for the MCP's query_sql (docs/mcp.md). One statement per call, sent through the extended query protocol,
  # which refuses `a; b` chains, with a five second statement_timeout.
  #
  # Reads (SELECT, WITH, TABLE, VALUES, EXPLAIN, SHOW) run in a read-only transaction that is always rolled back,
  # through a cursor so only `limit` rows are ever fetched. The read-only transaction is the fence; nothing a read
  # says can write.
  #
  # Writes (one INSERT, UPDATE or DELETE) never run from the MCP. `preview` runs the statement in a transaction that
  # is rolled back, records which rows it touched and what they looked like before and after, and an admin approves
  # it on /admin/sql_changes/:id (McpSqlChange). `execute!` runs it again only if it touches exactly the same rows
  # and those rows haven't changed since the preview; otherwise nothing is written.
  module Sql
    class Stale < StandardError; end

    TIMEOUT = "5s"
    READ_LIMIT = 100
    MAX_READ_LIMIT = 1_000
    MAX_WRITE_ROWS = 1_000
    PREVIEW_ROWS = 50
    CELL = 500
    READS = %w[select with table values explain show].freeze
    WRITES = %w[insert update delete].freeze
    # Functions that reach outside the transaction (settings, other sessions, files, locks that outlive it). The
    # read-only transaction stops most of them anyway; these are refused before the database sees them. Scanned over
    # the whole text, comments and strings included, so nothing can be hidden from the check.
    FORBIDDEN = /\b(set_config|setval|pg_terminate_backend|pg_cancel_backend|pg_reload_conf|pg_rotate_logfile|pg_read_file|pg_read_binary_file|
                   pg_ls_\w+|pg_stat_file|lo_\w+|dblink\w*|pg_advisory\w*|pg_notify|pg_logical\w*|pg_create\w*|pg_drop\w*|pg_switch_wal|
                   pg_promote|pg_import_system_collations)\s*\(/xi
    # Tables only their own code writes: the audit trail, the MCP's credentials and approvals, the schema's
    # bookkeeping, and the ones that have their own admin tools (jobs, flags).
    LOCKED_TABLES = %w[admin_tokens mcp_actions mcp_sql_changes versions schema_migrations ar_internal_metadata].freeze
    LOCKED_PREFIXES = %w[solid_ flipper_ active_insights_ active_storage_].freeze
    # Never shown in a preview or a read: encrypted tokens are ciphertext, but there is no reason to hand them out.
    MASKED_COLUMNS = %w[hca_token slack_user_token lapse_token token_digest].freeze
    TABLE_COLUMN = "__mcp_table"

    module_function

    def kind(sql)
      word = strip_comments(sql)[/\A\s*\(*\s*([a-z]+)/i, 1].to_s.downcase
      return word if WRITES.include?(word)
      return "read" if READS.include?(word)

      raise Mcp::Refused, "Only SELECT, WITH, TABLE, VALUES, EXPLAIN, SHOW, INSERT, UPDATE and DELETE are allowed. " \
                          "Schema changes go through a migration."
    end

    def read(sql, limit: nil)
      sql = clean(sql)
      limit = (limit || READ_LIMIT).to_i.clamp(1, MAX_READ_LIMIT)
      raise Mcp::Refused, "That is a write." unless kind(sql) == "read"

      columns = rows = nil
      transaction(read_only: true) do |pg|
        result =
          if strip_comments(sql) =~ /\A\s*(explain|show)\b/i
            exec(pg, sql)
          else
            exec(pg, "DECLARE mcp_read NO SCROLL CURSOR FOR #{sql}")
            exec(pg, "FETCH #{limit + 1} FROM mcp_read")
          end
        columns, rows = result.fields, result.values
      end
      { columns:, rows: rows.first(limit).map { display(columns, it) }, truncated: rows.size > limit }
    end

    # What a write would do, without doing it: { kind:, table:, count:, columns:, rows: [{ before:, after: }], keys:, digests: }.
    def preview(sql)
      sql = clean(sql)
      kind = kind(sql)
      raise Mcp::Refused, "That is a read." if kind == "read"
      raise Mcp::Refused, "Leave RETURNING out; the preview adds its own." if strip_comments(sql) =~ /\breturning\b/i

      plan = nil
      transaction(read_only: false) do |pg|
        pg.exec("SAVEPOINT mcp_dry_run")
        after = exec(pg, returning(sql))
        table = target_table(after)
        key = primary_key(table)
        raise Mcp::Refused, "#{table} has no primary key, so a preview can't pin down its rows." if key.nil? && kind != "insert"
        columns = after.fields - [ TABLE_COLUMN ]
        after_rows = after.values.map { it.drop(1) }
        pg.exec("ROLLBACK TO SAVEPOINT mcp_dry_run")
        before_rows = kind == "insert" ? {} : rows_by_key(pg, table, key, columns, after_rows.map { it[columns.index(key)] })
        raise Mcp::Refused, "It changes primary keys, which a preview can't follow." unless kind == "insert" || before_rows.size == after_rows.size
        plan = build_plan(kind, table, key, columns, after_rows, before_rows)
      end
      plan
    end

    # Runs an approved change. Raises Stale, writing nothing, when the rows aren't the ones the admin saw.
    def execute!(change)
      plan = change.preview
      count = nil
      transaction(read_only: false, commit: true) do |pg|
        table, key, columns = plan.values_at("table", "key", "columns")
        if change.kind != "insert"
          current = rows_by_key(pg, table, key, columns, plan["keys"], lock: true)
          raise Stale, "Some rows changed or went away since the preview." unless current.transform_values { digest(it) } == plan["digests"]
        end
        result = exec(pg, returning(clean(change.sql)))
        raise Mcp::Refused, "It wrote to #{target_table(result)}, not #{table}." unless target_table(result) == table
        count = result.ntuples
        keys = key && result.values.map { it.drop(1)[columns.index(key)] }
        raise Stale, "It would touch #{count} rows now, not #{plan['count']}." unless count == plan["count"]
        raise Stale, "It would touch different rows now." if change.kind != "insert" && keys.sort != plan["keys"].sort
      end
      count
    end

    def transaction(read_only:, commit: false)
      ActiveRecord::Base.transaction(requires_new: true) do
        connection = ActiveRecord::Base.connection
        connection.execute("SET LOCAL statement_timeout = '#{TIMEOUT}'")
        connection.execute("SET LOCAL transaction_read_only = on") if read_only
        yield connection.raw_connection
        raise ActiveRecord::Rollback unless commit
      end
    rescue PG::Error => e
      raise Mcp::Refused, e.message.lines.first.to_s.sub(/\AERROR:\s+/, "").strip.presence || e.class.name
    end

    def clean(sql)
      sql = sql.to_s.strip.sub(/;+\s*\z/, "")
      raise Mcp::Refused, "Give one SQL statement." if sql.empty?
      raise Mcp::Refused, "#{sql[FORBIDDEN, 1]} isn't allowed here." if sql.match?(FORBIDDEN)

      sql
    end

    def strip_comments(sql) = sql.to_s.gsub(%r{/\*.*?\*/}m, " ").gsub(/--[^\n]*/, " ")

    def returning(sql) = "#{sql} RETURNING tableoid::regclass::text AS #{TABLE_COLUMN}, *"

    def target_table(result)
      tables = result.column_values(0).uniq
      raise Mcp::Refused, "It matches no rows, so there is nothing to change." if tables.empty?
      raise Mcp::Refused, "It touches more than one table." if tables.size > 1

      table = tables.first.delete('"')
      if LOCKED_TABLES.include?(table) || LOCKED_PREFIXES.any? { table.start_with?(it) }
        raise Mcp::Refused, "#{table} can't be written with SQL. Use its own tool or page."
      end
      raise Mcp::Refused, "It touches #{result.ntuples} rows; #{MAX_WRITE_ROWS} is the most. Write a migration or a job." if result.ntuples > MAX_WRITE_ROWS

      table
    end

    def primary_key(table)
      key = ActiveRecord::Base.connection.primary_key(table)
      key.is_a?(String) ? key : nil
    end

    # { key => row values in `columns` order }, read with the same columns the write returned.
    def rows_by_key(pg, table, key, columns, keys, lock: false)
      connection = ActiveRecord::Base.connection
      select = columns.map { connection.quote_column_name(it) }.join(", ")
      sql = "SELECT #{select} FROM #{connection.quote_table_name(table)} WHERE #{connection.quote_column_name(key)}::text = ANY($1::text[])"
      sql += " FOR UPDATE" if lock
      encoder = PG::TextEncoder::Array.new
      exec(pg, sql, [ encoder.encode(keys) ]).values.to_h { [ it[columns.index(key)], it ] }
    end

    def build_plan(kind, table, key, columns, after_rows, before_rows)
      sample = after_rows.first(PREVIEW_ROWS).map do |after|
        before = before_rows[after[columns.index(key)]] if key
        case kind
        when "insert" then { after: display(columns, after) }
        when "delete" then { before: display(columns, before || after) }
        else { before: before && display(columns, before), after: display(columns, after) }
        end
      end
      {
        kind:, table:, key:, columns:, count: after_rows.size, rows: sample,
        keys: key && after_rows.map { it[columns.index(key)] },
        digests: before_rows.transform_values { digest(it) }
      }.as_json
    end

    def display(columns, values)
      columns.zip(values).map { |column, value| MASKED_COLUMNS.include?(column) && value ? "[hidden]" : Compact.clip(value, CELL) }
    end

    # Every value as Postgres's own text, so a fingerprint sees a microsecond's change and a key is always a string.
    def exec(pg, sql, params = []) = pg.exec_params(sql, params).tap { it.type_map = PG::TypeMapAllStrings.new }

    def digest(values) = OpenSSL::Digest::SHA256.hexdigest(JSON.generate(values))
  end
end
