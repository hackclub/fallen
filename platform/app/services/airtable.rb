# frozen_string_literal: true

# Airtable, where staff look at program data. AIRTABLE_API_KEY is a personal access token with
# data.records:read and data.records:write on AIRTABLE_BASE_ID. Airtable takes 10 records per request and 5
# requests a second per base, so requests are sent in tens with a pause between them.
module Airtable
  class Error < StandardError; end

  BATCH_SIZE = 10
  PAUSE = 0.25

  module_function

  def configured? = ENV["AIRTABLE_API_KEY"].present? && ENV["AIRTABLE_BASE_ID"].present?

  # Creates or updates records matched on merge_on. Fields are { "Column name" => value }; typecast lets Airtable
  # add select options it has not seen.
  def upsert(table, records, merge_on:)
    records.each_slice(BATCH_SIZE).with_index do |batch, i|
      sleep PAUSE if i.positive?
      request(:patch, table, {
        records: batch.map { |fields| { fields: fields } },
        performUpsert: { fieldsToMergeOn: Array(merge_on) },
        typecast: true
      })
    end
  end

  # Deletes every record whose field is one of values. Returns how many went.
  def delete_where(table, field, values)
    ids = values.each_slice(BATCH_SIZE).flat_map do |batch|
      formula = "OR(#{batch.map { |value| "{#{field}} = '#{value.to_s.gsub(/['\\]/) { "\\#{it}" }}'" }.join(', ')})"
      request(:get, table, nil, filterByFormula: formula, "fields[]": field)["records"].pluck("id")
    end
    ids.each_slice(BATCH_SIZE) { |batch| request(:delete, table, nil, "records[]": batch) }
    ids.size
  end

  def request(method, table, body, params = {})
    response = connection.run_request(method, "v0/#{ENV.fetch('AIRTABLE_BASE_ID')}/#{ERB::Util.url_encode(table)}", body&.to_json, nil) do |req|
      req.params.update(params)
    end
    raise Error, "Airtable #{method} #{table} failed: #{response.status} #{response.body.to_s.truncate(300)}" unless response.success?

    JSON.parse(response.body)
  end

  def connection
    Faraday.new(url: "https://api.airtable.com", headers: { "Authorization" => "Bearer #{ENV.fetch('AIRTABLE_API_KEY')}", "Content-Type" => "application/json" }) do |f|
      f.options.params_encoder = Faraday::FlatParamsEncoder
      f.options.timeout = 30
      f.options.open_timeout = 5
    end
  end
end
