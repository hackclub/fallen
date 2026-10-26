# frozen_string_literal: true

# Airtable, where staff look at program data. Tables are filled through the Sync API: each upload is the whole table
# as CSV, and Airtable adds, updates and (with the table's default deletion setting) removes records to match it.
# AIRTABLE_API_KEY is a personal access token with data.records:read, data.records:write and schema.bases:write on
# AIRTABLE_BASE_ID (read for ProjectTransfer), and data.records:read on Fallout's base (FalloutInvite).
# https://airtable.com/developers/web/api/post-sync-api-endpoint
module Airtable
  class Error < StandardError; end

  MAX_ROWS = 10_000
  MAX_BYTES = 2.megabytes

  module_function

  def configured? = ENV["AIRTABLE_API_KEY"].present? && ENV["AIRTABLE_BASE_ID"].present?

  # Rows are hashes with the same keys, which become the column names. Airtable takes 10k rows and 2 MB per upload,
  # and anything bigger is refused here rather than half synced. Each upload is the whole table, so one that couldn't
  # connect or timed out can be sent again.
  def sync(table, sync_id, rows)
    raise Error, "Airtable sync of #{table} has #{rows.size} rows, over #{MAX_ROWS}" if rows.size > MAX_ROWS

    body = csv(rows)
    raise Error, "Airtable sync of #{table} is #{body.bytesize} bytes, over #{MAX_BYTES}" if body.bytesize > MAX_BYTES

    response = with_retries { connection.post("v0/#{ENV.fetch('AIRTABLE_BASE_ID')}/#{ERB::Util.url_encode(table)}/sync/#{ERB::Util.url_encode(sync_id)}", body, "Content-Type" => "text/csv") }
    raise Error, "Airtable sync of #{table} failed: #{response.status} #{response.body.to_s.truncate(300)}" unless response.success?

    JSON.parse(response.body)
  end

  # Every record's fields, keyed by field id so a renamed column keeps working. A page is 100 records, and Airtable
  # allows 5 requests a second per base. A page that can't connect or times out is asked for again a couple of times,
  # since a big table is dozens of pages and one dropped connection would otherwise throw the rest away. With
  # `whole: true` each record comes as Airtable sends it, with its id and createdTime around the fields.
  def records(base, table, fields:, whole: false)
    pages = []
    offset = nil
    loop do
      response = with_retries { connection.get("v0/#{base}/#{table}", { pageSize: 100, returnFieldsByFieldId: true, fields: fields, offset: offset }.compact) }
      raise Error, "Airtable read of #{table} failed: #{response.status} #{response.body.to_s.truncate(300)}" unless response.success?

      page = JSON.parse(response.body)
      pages << (whole ? page["records"] : page["records"].map { it["fields"] })
      break unless (offset = page["offset"])

      sleep 0.25
    end
    pages.flatten(1)
  end

  def with_retries(attempts: 3)
    attempt = 0
    begin
      attempt += 1
      yield
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError
      raise if attempt >= attempts

      sleep 2**attempt
      retry
    end
  end

  def csv(rows) = ([ rows.first.keys ] + rows.map(&:values)).map { |cells| cells.map { |cell| csv_cell(cell) }.join(",") + "\n" }.join

  # RFC 4180: a cell with a comma, quote or line break is quoted, with quotes doubled. Arrays become multiple select.
  def csv_cell(value)
    text = value.is_a?(Array) ? value.join(",") : value.to_s
    text.match?(/[",\r\n]/) ? "\"#{text.gsub('"', '""')}\"" : text
  end

  def connection
    Faraday.new(url: "https://api.airtable.com", headers: { "Authorization" => "Bearer #{ENV.fetch('AIRTABLE_API_KEY')}" }) do |f|
      f.options.timeout = 60
      f.options.open_timeout = 5
    end
  end
end
