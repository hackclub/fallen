require "test_helper"

class BomExtractionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  CSV_TEXT = <<~CSV
    #,Componnet,Qty,Price ea,Line,Where
    1,"Resistr 10k, 1/4W",9,$0.32,$2.88,https://lcsc.com/r
    2,ESP-32 devkit,1,"$4,50",,https://amazon.com/esp
    ,Shipping,,,$5.00,
    ,TOTAL,,,$12.38,
  CSV

  def answer(items, stated_total: "$12.38") = { "items" => items, "stated_total" => stated_total }

  def row(**fields) = { "kind" => "part", "purpose" => nil, "quantity" => nil, "unit_price" => nil, "total_price" => nil, "link" => nil, "vendor" => nil, "owned" => false }.merge(fields.stringify_keys)

  FAITHFUL = [
    { name: "Resistr 10k, 1/4W", quantity: "9", unit_price: "$0.32", total_price: "$2.88", link: "https://lcsc.com/r" },
    { name: "ESP-32 devkit", quantity: "1", unit_price: "$4,50", link: "https://amazon.com/esp" },
    { kind: "shipping", name: "Shipping", total_price: "$5.00" }
  ].freeze

  test "keeps every name exactly as written, typos and all, and works the money out itself" do
    with_model(answer(FAITHFUL.map { row(**it) })) do
      result = BomExtraction.read(CSV_TEXT)

      assert_equal "model", result.source
      assert_equal [ "Resistr 10k, 1/4W", "ESP-32 devkit", "Shipping" ], result.items.map(&:name)
      assert_equal [ 9, 1, 1 ], result.items.map(&:quantity)
      assert_equal [ 288, 450, 500 ], result.items.map(&:total_cents)
      assert_equal 32, result.items.first.unit_cents
      assert_equal %w[part part shipping], result.items.map(&:kind)
      assert_equal 1238, result.stated_total_cents
      assert_empty result.warnings
    end
  end

  test "a cell typed back with a plain space keeps the file's own spacing" do
    csv = "Part,Qty,Price\n4.7\u202FµF cap,2,$0.10\n"
    with_model(answer([ row(name: "4.7 µF cap", quantity: "2", unit_price: "$0.10") ], stated_total: nil)) do
      result = BomExtraction.read(csv)

      assert_equal "model", result.source
      assert_equal "4.7\u202FµF cap", result.items.first.name
    end
  end

  test "an answer that rewords anything is thrown away for the plain parser" do
    corrected = FAITHFUL.map { row(**it) }.tap { it[0] = it[0].merge("name" => "Resistor 10k, 1/4W") }
    shortened = FAITHFUL.map { row(**it) }.tap { it[1] = it[1].merge("name" => "ESP-32") }
    made_up = FAITHFUL.map { row(**it) }.tap { it[1] = it[1].merge("purpose" => "The brains of the build") }

    [ corrected, shortened, made_up ].each do |items|
      with_model(answer(items)) { assert_equal "parser", BomExtraction.read(CSV_TEXT).source }
    end
  end

  test "falls back to the plain parser when the model fails, answers nothing or isn't set up" do
    with_model(OpenRouter::Error.new("down")) { assert_equal "parser", BomExtraction.read(CSV_TEXT).source }
    with_model(answer([])) { assert_equal "parser", BomExtraction.read(CSV_TEXT).source }
    with_env("OPENROUTER_API_KEY" => nil) { assert_equal "parser", BomExtraction.read(CSV_TEXT).source }
  end

  test "a repository check with a bom.csv has it read in the background, once" do
    project = projects(:station)
    snapshot = RepoSnapshot.create!(project:, user: project.user, url: "https://github.com/someone/thing")
    data = GitRemote::Snapshot.new(url: snapshot.url, host: "github.com", branch: "main", commit_sha: "a" * 40, tree: [], tree_truncated: false,
      readme_path: nil, readme: nil, bom_path: "bom.csv", bom_csv: CSV_TEXT)

    stub_method(GitRemote, :snapshot, data) do
      assert_enqueued_with(job: BomExtractionJob, args: [ snapshot ]) { snapshot.fetch! }
    end
    assert_equal "pending", snapshot.bom_state

    with_model(answer(FAITHFUL.map { row(**it) })) { BomExtractionJob.perform_now(snapshot) }
    assert_equal "done", snapshot.reload.bom_state
    assert_equal [ "Resistr 10k, 1/4W", "ESP-32 devkit", "Shipping" ], snapshot.bom_items.map(&:name)
    assert_equal "model", snapshot.bom_import["source"]

    with_model(OpenRouter::Error.new("should not be asked again")) { BomExtractionJob.perform_now(snapshot) }
    assert_equal "model", snapshot.reload.bom_import["source"]
  end

  test "checking again with the same bom.csv reuses the last reading instead of asking the model" do
    project = projects(:station)
    first = RepoSnapshot.create!(project:, user: project.user, url: "https://github.com/someone/thing", status: "done", bom_csv: CSV_TEXT)
    with_model(answer(FAITHFUL.map { row(**it) })) { first.read_bom! }

    again = RepoSnapshot.create!(project:, user: project.user, url: first.url, status: "done", bom_csv: CSV_TEXT)
    with_model(OpenRouter::Error.new("should not be asked")) { again.read_bom! }
    assert_equal first.reload.bom_import, again.reload.bom_import

    changed = RepoSnapshot.create!(project:, user: project.user, url: first.url, status: "done", bom_csv: "#{CSV_TEXT}Wire,1,$2\n")
    with_model(OpenRouter::Error.new("down")) { changed.read_bom! }
    assert_equal "parser", changed.reload.bom_import["source"]
  end

  test "a check whose read never happened has it queued again, but not while it's fresh or already read" do
    project = projects(:station)
    snapshot = RepoSnapshot.create!(project:, user: project.user, url: "https://github.com/someone/thing", status: "done", bom_csv: CSV_TEXT, fetched_at: 1.minute.ago)
    assert_no_enqueued_jobs(only: BomExtractionJob) { snapshot.read_bom_later }

    snapshot.update!(fetched_at: 10.minutes.ago)
    assert_enqueued_with(job: BomExtractionJob, args: [ snapshot ]) { snapshot.read_bom_later }

    snapshot.update!(bom_import: { "items" => [] })
    assert_no_enqueued_jobs(only: BomExtractionJob) { snapshot.read_bom_later }
  end

  private

  # Answers OpenRouter.json with `reply`, or raises it when it's an error.
  def with_model(reply)
    original = OpenRouter.method(:json)
    OpenRouter.define_singleton_method(:json) { |**| reply.is_a?(Exception) ? raise(reply) : reply }
    with_env("OPENROUTER_API_KEY" => "test") { yield }
  ensure
    OpenRouter.define_singleton_method(:json, original)
  end
end
