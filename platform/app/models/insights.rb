# frozen_string_literal: true

# Request and job timings for /admin/insights, read from the ActiveInsights tables that InsightsBuffer fills in
# production. Each method is one grouped query over the chosen range, optionally narrowed to one endpoint or job.
class Insights
  # Range => [span, chart bucket]. Rows older than 30 days are deleted (config/recurring.yml).
  RANGES = {
    "1h" => [ 1.hour, 1.minute ],
    "24h" => [ 1.day, 15.minutes ],
    "7d" => [ 7.days, 2.hours ],
    "30d" => [ 30.days, 12.hours ]
  }.freeze
  DEFAULT_RANGE = "24h"
  KINDS = %w[requests jobs].freeze
  TOP = 100
  SLOWEST = 25

  attr_reader :kind, :range, :name

  def initialize(kind:, range:, name: nil, now: Time.current)
    @kind = KINDS.include?(kind) ? kind : KINDS.first
    @range = RANGES.key?(range) ? range : DEFAULT_RANGE
    @name = name.presence
    @span, @bucket = RANGES.fetch(@range)
    @to = now
    # Buckets line up on whole intervals and the last one holds now, so a range always has span / bucket of them.
    @from = Time.zone.at((now.to_i / @bucket.to_i) * @bucket.to_i) - @span + @bucket
  end

  def requests? = kind == "requests"

  def summary
    row = scope.pick(*aggregates.values.map { Arel.sql(it) })
    stats = rounded(aggregates.keys.zip(row).to_h)
    stats.merge(per_minute: (stats[:count] / (@span / 60.0)).round(2))
  end

  # One point per bucket, empty buckets included, so the chart's x axis is the whole range.
  def series
    bucket = scope.sanitize_sql_array([ "date_bin(?::interval, started_at, ?)", "#{@bucket.to_i} seconds", @from ])
    columns = %i[count errors p50 p95]
    rows = scope.group(Arel.sql(bucket)).pluck(Arel.sql(bucket), *columns.map { Arel.sql(aggregates[it] || "0") })
      .to_h { |at, *values| [ at.to_i, rounded(columns.zip(values).to_h) ] }

    (@from.to_i..@to.to_i).step(@bucket.to_i).map do |at|
      { at: Time.zone.at(at).iso8601, **rows.fetch(at) { { count: 0, errors: 0, p50: nil, p95: nil } } }
    end
  end

  # The endpoints or jobs that cost the most time in total, which is where speeding things up pays off.
  def breakdown
    columns = aggregates.except(:p99).merge(total: "SUM(duration)", **({ queue: "MAX(queue)" } unless requests?))
    scope.group(name_column).order(Arel.sql("SUM(duration) DESC")).limit(TOP)
      .pluck(Arel.sql(name_column), *columns.values.map { Arel.sql(it) })
      .map { |name, *values| { name:, **rounded(columns.keys.zip(values).to_h) } }
  end

  def slowest
    fields = requests? ? %i[started_at duration status http_method path db_runtime view_runtime] : %i[started_at duration queue_time queue db_runtime]
    scope.order(duration: :desc).limit(SLOWEST).pluck(name_column, *fields)
      .map { |name, *values| { name:, **rounded(fields.zip(values).to_h) } }
  end

  # How the responses split by status class: 2xx, 3xx, 4xx, 5xx.
  def statuses
    return [] unless requests?

    scope.group(Arel.sql("status / 100")).order(Arel.sql("status / 100")).count
      .map { |klass, count| { status: "#{klass.to_i}xx", count: } }
  end

  private

  def model = requests? ? ActiveInsights::Request : ActiveInsights::Job
  def name_column = requests? ? "formatted_controller" : "job"

  def scope
    rows = model.where(started_at: @from..@to)
    name ? rows.where(name_column => name) : rows
  end

  def rounded(values)
    values.transform_values do |value|
      case value
      when Float, BigDecimal then value.to_f.round(1)
      when Time then value.iso8601
      else value
      end
    end
  end

  def aggregates
    @aggregates ||= {
      count: "COUNT(*)",
      errors: (requests? ? "COUNT(*) FILTER (WHERE status >= 500)" : nil),
      avg: "AVG(duration)",
      p50: "PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration)",
      p95: "PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration)",
      p99: "PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration)",
      max: "MAX(duration)",
      db: "AVG(db_runtime)",
      queue_p95: (requests? ? nil : "PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY queue_time)")
    }.compact
  end
end
