require "csv"

# Reads the bom.csv in someone's repository into the rows of their parts list, so the submit popup starts filled in.
# A model (through OpenRouter) only decides which cell is which: the name, the price, the link, whether a row is
# shipping or a total. It hands back every cell's text as written and the money is worked out here, so nothing in
# the list is reworded, corrected or made up. An answer that isn't made of the file's own cells is thrown away, and
# so is any failure: then the plain parser (BomImport) reads the file instead, so this always has an answer.
class BomExtraction
  # Matching cells to fields is easy work: a small model thinking a little does it for a twentieth of Sonnet's price,
  # and a reading that isn't faithful falls back to BomImport anyway.
  MODEL = "anthropic/claude-haiku-5.5"
  EFFORT = "low"
  MAX_TOKENS = 32_000

  SYSTEM = <<~PROMPT
    You turn a bill of materials (a CSV file someone wrote for their hardware project) into structured rows.

    Copy text exactly. Every string you return must be the full text of one cell of the file, character for
    character: the same spelling, typos, capitals, spacing, punctuation and units. Never fix, translate, shorten,
    expand, merge or reword anything, and never put in text that isn't in the file. If a field has no cell, use null.
    Do not judge or flag anything about the parts, their names or their prices; just read them.

    For each row that is something to buy (or something the person already owns), in file order:
    - kind: "shipping" for shipping or delivery, "tax" for tax, VAT or duties, otherwise "part".
    - name: the cell naming the part.
    - purpose: the cell saying what it's for or describing it, or null.
    - quantity: the cell with how many, or null.
    - unit_price: the cell with the price of one, or null.
    - total_price: the cell with the price of the whole line, or null.
    - link: the cell with the URL to buy it, or null.
    - vendor: the cell naming the store or supplier, or null.
    - owned: true only if the file says they already have it (a column such as "owned" or "have it", or a price
      cell saying so); otherwise false.
    Leave out header rows, blank rows, section titles and total or subtotal rows. Put the cell of the file's grand
    total in stated_total (or null if there isn't one).
  PROMPT

  NULLABLE = { type: %w[string null] }.freeze
  SCHEMA = {
    type: "object", additionalProperties: false, required: %w[items stated_total],
    properties: {
      stated_total: NULLABLE,
      items: {
        type: "array",
        items: {
          type: "object", additionalProperties: false,
          required: %w[kind name purpose quantity unit_price total_price link vendor owned],
          properties: {
            kind: { type: "string", enum: %w[part shipping tax] }, name: { type: "string" }, purpose: NULLABLE,
            quantity: NULLABLE, unit_price: NULLABLE, total_price: NULLABLE, link: NULLABLE, vendor: NULLABLE,
            owned: { type: "boolean" }
          }
        }
      }
    }
  }.freeze
  TEXT_FIELDS = %w[name purpose quantity unit_price total_price link vendor].freeze

  # Raised when the model's answer can't be trusted as a reading of the file.
  class Mismatch < StandardError; end

  def self.read(csv) = new(csv).result

  def initialize(csv)
    @text = csv.to_s.byteslice(0, BomImport::MAX_BYTES).force_encoding(Encoding::UTF_8).scrub.delete_prefix("﻿")
  end

  # The rows, from the model when it read the file faithfully, otherwise from BomImport.
  def result
    return parsed unless OpenRouter.configured?

    answer = OpenRouter.json(model: MODEL, effort: EFFORT, system: SYSTEM, user: @text, schema: SCHEMA, max_tokens: MAX_TOKENS)
    items = answer.fetch("items").first(BomImport::MAX_ROWS).map { |row| item(row) }
    raise Mismatch, "no rows" if items.empty?

    warnings = []
    warnings << "Some prices look like they aren't in US dollars. Convert them to USD." if @text.match?(BomImport::OTHER_CURRENCY)
    Result.new(items:, stated_total_cents: answer["stated_total"].presence && BomImport.cents(verbatim!(answer["stated_total"])), mapping: {}, warnings:, source: "model")
  rescue OpenRouter::Error, Mismatch, KeyError, TypeError, NoMethodError => e
    Rails.error.report(e, handled: true, context: { bom_extraction: e.class.name })
    parsed
  end

  # BomImport::Result plus which reader made it.
  Result = Data.define(:items, :stated_total_cents, :mapping, :warnings, :source)

  private

  def parsed = Result.new(**BomImport.parse(@text).to_h, source: "parser")

  def item(row)
    raise Mismatch, "row isn't an object" unless row.is_a?(Hash)

    row = row.merge(TEXT_FIELDS.index_with { |field| row[field].present? ? verbatim!(row[field]) : nil })
    kind = %w[part shipping tax].include?(row["kind"]) ? row["kind"] : "part"
    quantity = row["quantity"].to_s[/\d+/]&.to_i
    quantity = 1 if quantity.nil? || quantity < 1 || kind != "part"
    unit = row["unit_price"].presence && BomImport.cents(row["unit_price"])
    total = row["total_price"].presence && BomImport.cents(row["total_price"])
    total ||= unit && unit * quantity
    unit ||= total && (total.to_f / quantity).round

    BomImport::Item.new(kind:, name: row["name"].to_s.truncate(BomItem::MAX_NAME), purpose: row["purpose"].presence&.truncate(BomItem::MAX_PURPOSE),
      quantity:, unit_cents: unit, total_cents: total, link: row["link"].to_s.strip.presence&.then { |l| l.truncate(BomItem::MAX_LINK) if l.match?(BomItem::URL) },
      vendor: row["vendor"].presence&.truncate(100), owned: row["owned"] == true)
  end

  # The file's own cell for the text the model gave. Models type an odd space or a lookalike letter as the plain
  # one, so cells are matched with Unicode and spacing evened out, but what's kept is always the cell as written.
  # A file CSV can't split cleanly is matched against its whole text instead.
  def verbatim!(text)
    value = text.to_s.strip
    if cells.any?
      cells.fetch(comparable(value)) { raise Mismatch, "not in the file: #{value.truncate(80)}" }
    else
      @text.include?(value) ? value : raise(Mismatch, "not in the file: #{value.truncate(80)}")
    end
  end

  def comparable(text) = text.unicode_normalize(:nfkc).gsub(/[[:space:]]+/, " ").strip

  def cells
    @cells ||= begin
      separator = [ ",", ";", "\t" ].max_by { |s| @text.lines.first(3).sum { |line| line.count(s) } }
      CSV.parse(@text, col_sep: separator, liberal_parsing: true).flatten.compact.map(&:strip).reject(&:empty?).index_by { comparable(it) }
    rescue CSV::MalformedCSVError
      {}
    end
  end
end
