require "csv"

# Turns whatever bom.csv someone made (any column names and order, commas or semicolons, "$1,234.50" or "1.234,50 €",
# shipping and total rows mixed in with the parts) into BomItem rows they then check and fix by hand. It never
# fails: what it can't read comes back empty for them to fill in, with a warning saying so.
class BomImport
  MAX_BYTES = 200.kilobytes
  MAX_ROWS = 200

  FIELDS = {
    name: /\A(?:item|part|parts?\s*name|name|component|product|title|thing)s?\b/i,
    purpose: /purpose|use[ds]?\b|why|function|notes?|comment|description|desc\b|details?/i,
    quantity: /\A(?:qty|quantity|quantities|count|#|pcs|pieces|units|number)\b/i,
    unit: /unit|each|per\s|\/\s*(?:unit|pc|piece|ea)|price(?!.*total)/i,
    total: /total|subtotal|line|extended|\bcost\b|amount|sum\b|usd|\$/i,
    link: /link|url|source|where|buy|purchase|href|website/i,
    vendor: /vendor|supplier|store|shop|seller|distributor|retailer|\bfrom\b|merchant/i,
    owned: /\b(?:own(?:ed)?|have|already|in\s*stock)\b/i
  }.freeze
  SUMMARY = /\A\s*(?:grand\s*|sub\s*|estimated\s*)?total\b/i
  SHIPPING = /shipping|delivery|postage|freight|courier/i
  TAX = /\btax(?:es)?\b|\bvat\b|\bgst\b|\bhst\b|duties|customs|tariff/i
  YES = /\A\s*(?:y|yes|true|x|✓|✔|owned|have|have it|already own(?:ed)?)\s*\z/i
  OTHER_CURRENCY = /€|£|¥|₹|\b(?:eur|gbp|cny|rmb|inr|cad|aud|jpy)\b/i

  Item = Data.define(:kind, :name, :purpose, :quantity, :unit_cents, :total_cents, :link, :vendor, :owned)
  Result = Data.define(:items, :stated_total_cents, :mapping, :warnings)

  def self.parse(text) = new(text).result

  def initialize(text)
    @text = text.to_s.byteslice(0, MAX_BYTES).force_encoding(Encoding::UTF_8).scrub.delete_prefix("﻿")
    @warnings = []
  end

  def result
    rows = read_rows
    return Result.new(items: [], stated_total_cents: nil, mapping: {}, warnings: [ "That file has no rows" ]) if rows.empty?

    header_at = rows.first(5).index { |row| header_score(row) >= 2 }
    @warnings << "There's no header row, so the columns were guessed. Check every row." unless header_at
    headers = header_at ? rows[header_at] : []
    columns = map_columns(headers, rows[(header_at ? header_at + 1 : 0)..])
    items = []
    stated = nil
    rows[(header_at ? header_at + 1 : 0)..].each do |row|
      break if items.size >= MAX_ROWS

      item, summary = build(row, columns)
      if summary then stated = summary
      elsif item then items << item
      end
    end
    @warnings << "Only the first #{MAX_ROWS} rows were read" if rows.size - (header_at || -1) - 1 > MAX_ROWS
    @warnings << "Some prices look like they aren't in US dollars. Convert them to USD." if @text.match?(OTHER_CURRENCY)
    sum = items.reject(&:owned).sum { |item| item.total_cents.to_i }
    if stated && (stated - sum).abs > 100
      @warnings << "The file's own total (#{Money.format(stated)}) doesn't match its rows (#{Money.format(sum)}). The rows are what count."
    end

    Result.new(items:, stated_total_cents: stated, mapping: columns.transform_values { |i| headers[i] }, warnings: @warnings)
  end

  # "$1,234.50", "1.234,50 €", "12 USD", "3", "free" -> cents, or nil when there's no number in it.
  def self.cents(text)
    s = text.to_s.strip
    return 0 if s.match?(/\A(?:free|0|-|n\/a)\z/i)

    number = s[/-?\d[\d.,\s']*/]&.gsub(/[\s']/, "") or return nil
    if number.include?(",") && number.include?(".")
      number = number.rindex(",") > number.rindex(".") ? number.delete(".").tr(",", ".") : number.delete(",")
    elsif number.count(",") == 1 && number[/,(\d+)\z/, 1]&.length.to_i <= 2
      number = number.tr(",", ".")
    else
      number = number.delete(",")
    end
    (BigDecimal(number) * 100).round.to_i.abs
  rescue ArgumentError
    nil
  end

  private

  def read_rows
    separator = [ ",", ";", "\t" ].max_by { |s| @text.lines.first(3).sum { |line| line.count(s) } }
    CSV.parse(@text, col_sep: separator, liberal_parsing: true, skip_blanks: true)
      .map { |row| row.map { |cell| cell.to_s.strip } }
      .reject { |row| row.all?(&:empty?) }
  rescue CSV::MalformedCSVError
    @warnings << "Part of the file couldn't be read as CSV"
    @text.lines.map { |line| line.split(separator).map(&:strip) }
  end

  def header_score(row) = row.count { |cell| !cell.match?(/\d{2,}|https?:/) && FIELDS.values.any? { |pattern| cell.match?(pattern) } }

  # Column index for each field. Earlier fields win a column, and money columns are told apart by what else is there.
  def map_columns(headers, body)
    taken = {}
    %i[quantity link vendor owned total unit name purpose].each do |field|
      index = headers.each_index.find { |i| !taken.value?(i) && headers[i].match?(FIELDS[field]) && !(field == :total && headers[i].match?(FIELDS[:unit]) && !headers[i].match?(/total/i)) }
      taken[field] = index if index
    end
    taken[:name] ||= headers.each_index.find { |i| !taken.value?(i) } || 0
    taken[:link] ||= (0...(body.map(&:size).max || 0)).find { |i| !taken.value?(i) && body.count { |row| row[i].to_s.match?(%r{\Ahttps?://}) } > body.size / 3 }
    # One money column: a total if it says so, otherwise a price per unit when there's a quantity.
    if taken[:unit] && !taken[:total] && !headers[taken[:unit]].match?(/unit|each|per/i) && !taken[:quantity]
      taken[:total] = taken.delete(:unit)
    end
    taken.compact
  end

  def build(row, columns)
    cell = ->(field) { columns[field] && row[columns[field]].to_s.strip.presence }
    name = cell.(:name) || row.find { |c| c.present? && !c.match?(%r{\Ahttps?://}) && BomImport.cents(c).nil? }
    return nil if name.blank?

    total = cell.(:total) && BomImport.cents(cell.(:total))
    # No header row: a bare whole number is the quantity and the first amount of money is the line's total.
    if columns.keys == %i[name] || columns.keys.sort == %i[link name]
      rest = row - [ name ]
      quantity_cell = rest.find { |c| c.match?(/\A\d{1,5}\z/) }
      total = rest.excluding(quantity_cell).filter_map { |c| BomImport.cents(c) unless c.match?(%r{\Ahttps?://}) }.first
    end
    return [ nil, total || (row - [ name ]).filter_map { |c| BomImport.cents(c) unless c.match?(%r{\Ahttps?://}) }.first ] if name.match?(SUMMARY)

    quantity = (cell.(:quantity) || quantity_cell).to_s[/\d+/]&.to_i
    quantity = 1 if quantity.nil? || quantity < 1
    unit = cell.(:unit) && BomImport.cents(cell.(:unit))
    total ||= unit && unit * quantity
    unit ||= total && quantity.positive? ? (total.to_f / quantity).round : nil
    owned = cell.(:owned).to_s.match?(YES) || [ cell.(:unit), cell.(:total) ].compact.any? { |c| c.match?(/own|have it/i) }
    kind = if name.match?(SHIPPING) then "shipping" elsif name.match?(TAX) then "tax" else "part" end
    link = [ cell.(:link), *row ].compact.find { |c| c.match?(BomItem::URL) }

    [ Item.new(kind:, name: name.truncate(BomItem::MAX_NAME), purpose: cell.(:purpose)&.truncate(BomItem::MAX_PURPOSE), quantity: kind == "part" ? quantity : 1,
      unit_cents: unit, total_cents: total, link: link&.truncate(BomItem::MAX_LINK), vendor: cell.(:vendor)&.truncate(100), owned:), nil ]
  end
end
