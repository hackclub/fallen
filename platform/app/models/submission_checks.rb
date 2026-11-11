# The checks a design submission must pass before it goes in the queue, run the same way in the submit popup and
# again when it is sent (Submission.submit), so the popup can't be skipped. A failed check blocks; a warning is
# shown to the person and to the reviewer. Built from what we already have (the RepoSnapshot, the journals), so it
# never touches the network.
class SubmissionChecks
  MADE_WITH = %w[pcb cad firmware].freeze
  PCB_SOURCE = /\.(?:kicad_pcb|kicad_sch|kicad_pro|brd|sch|pcbdoc|schdoc|prjpcb|epro|eprj|fzz|lch|dip)\z/i
  GERBERS = /gerber|\.(?:gbr|gtl|gbl|gto|gbo|gts|gbs|gko|gm1|drl|xln)\z/i
  STEP = /\.(?:step|stp)\z/i
  CAD_SOURCE = /\.(?:f3d|f3z|fcstd|scad|blend|sldprt|sldasm|ipt|iam|skp|3dm|shapr|onshape)\z/i
  FIRMWARE = /\.(?:ino|c|cc|cpp|h|hpp|py|rs|go|zig|ts|js|uf2|hex|elf|toml|yaml|yml|json)\z/i
  # Parts the funding docs ask people to design rather than buy (docs/project-funding.mdx).
  READY_MADE = /\b(?:dev\s*(?:board|kit)|development\s*board|arduino|esp32[-\s]?(?:devkit|wroom[-\s]?devkit|c3[-\s]?super\s*mini)|nodemcu|wemos|d1\s*mini|raspberry\s*pi\s*pico|pico\s*w?\b|feather|xiao|breakout|module)\b/i
  IMAGE = /!\[[^\]]*\]\([^)]+\)|<img\b/i
  SELF_CLAIMED_SHARE = 0.5

  # A detail with a doc names a page under /docs; the [bracketed] words in it link there.
  Check = Data.define(:key, :label, :status, :detail, :doc)

  def self.blocking?(checks) = checks.any? { |check| check["status"] == "fail" }

  def initialize(project:, snapshot:, made_with:, screenshots:, items:)
    @project = project
    @snapshot = snapshot
    @made_with = Array(made_with) & MADE_WITH
    @screenshots = screenshots
    @items = items
  end

  def run
    [ *repo_checks, screenshot_check, *bom_checks, *journal_checks ].compact.map { |check| check.to_h.transform_keys(&:to_s) }
  end

  private

  def check(key, label, ok, detail, level: "fail", doc: nil) = Check.new(key:, label:, status: ok ? "pass" : level, detail: ok ? nil : detail, doc: ok ? nil : doc)

  def repo_checks
    unless @snapshot&.done?
      return [ check("repo", "Repository is public", false, @snapshot&.error || "Check your repository first") ]
    end
    return [ check("repo", "Repository is up to date", false, "It was read over #{RepoSnapshot::FRESH_FOR.inspect} ago. Check it again.") ] unless @snapshot.fresh?

    paths = @snapshot.paths
    [
      check("repo", "Repository is public", true, nil),
      check("readme", "Has a README", @snapshot.readme_path.present?, "Add a README.md that says what your project is, why you made it and how to use it."),
      (check("readme_images", "README has pictures", @snapshot.readme.to_s.match?(IMAGE), "Show your 3D model, PCB and schematic in the README.", level: "warn") if @snapshot.readme_path),
      *(@made_with.include?("pcb") ? pcb_checks(paths) : []),
      *(@made_with.include?("cad") ? cad_checks(paths) : []),
      (check("firmware", "Firmware is in the repo", paths.any? { |p| p.match?(FIRMWARE) }, "Add your firmware's source code.") if @made_with.include?("firmware")),
      check("repo_bom", "bom.csv is in the repo", @snapshot.bom_path.present? && @snapshot.bom_csv.present?,
        @snapshot.bom_path.present? ? "#{@snapshot.bom_path} in your repo is empty. Commit the parts list there too." : "Commit your bom.csv too, so the repo has everything.",
        level: "warn")
    ]
  end

  def pcb_checks(paths)
    [ check("pcb_source", "PCB source files", paths.any? { |p| p.match?(PCB_SOURCE) }, "Add your PCB project (for KiCad: .kicad_pro, .kicad_sch and .kicad_pcb)."),
      check("gerbers", "Gerbers", paths.any? { |p| p.match?(GERBERS) }, "Add your gerbers (a gerbers.zip is fine) so it can be made.", level: "warn") ]
  end

  def cad_checks(paths)
    onshape = @snapshot.readme.to_s.match?(/cad\.onshape\.com/i)
    [ check("step", "STEP files", paths.any? { |p| p.match?(STEP) }, "Export a .step of each part you modeled."),
      check("cad_source", "CAD source", onshape || paths.any? { |p| p.match?(CAD_SOURCE) }, "Add your CAD source file (.f3d, .FCStd...) or an Onshape link in the README.", level: "warn") ]
  end

  def screenshot_check = check("screenshot", "Screenshot", @screenshots.positive?, "Add a screenshot that shows off your design.")

  def bom_checks
    parts = @items.select { |item| item.kind == "part" && !item.owned }
    missing = parts.reject { |item| item.link.present? && item.total_cents.to_i.positive? }
    ready_made = parts.select { |item| item.name.to_s.match?(READY_MADE) }
    [
      check("bom", "Bill of materials", @items.any? && @items.sum { |item| item.owned ? 0 : item.total_cents.to_i }.positive?, "Add the parts you need, with prices."),
      check("bom_lines", "Every part has a link and price", missing.empty?, "#{missing.first(3).map(&:name).to_sentence}#{" and more" if missing.size > 3} #{missing.one? ? "needs" : "need"} a link and a price."),
      check("bom_ready_made", "No ready-made boards", ready_made.size <= 1, "#{ready_made.first(3).map(&:name).to_sentence} look ready-made. Funding is for parts of your own design.", level: "warn"),
      repo_bom_check
    ].compact
  end

  # The repo's bom.csv and the one in the popup should be the same list.
  def repo_bom_check
    return unless @snapshot&.bom_csv.present? && @items.any?

    rows = @snapshot.bom_state == "done" ? @snapshot.bom_items : BomImport.parse(@snapshot.bom_csv).items
    theirs = rows.reject(&:owned).sum { |item| item.total_cents.to_i }
    ours = @items.reject(&:owned).sum { |item| item.total_cents.to_i }
    check("bom_matches_repo", "Matches the repo's bom.csv", (theirs - ours).abs <= [ ours / 20, 100 ].max,
      "The repo's bom.csv adds up to #{Money.format(theirs)} but this one is #{Money.format(ours)}. Update the one in your repo.", level: "warn")
  end

  def journal_checks
    journals = @project.journals.kept.written_here
    logged = journals.where.not(duration_minutes: nil)
    minutes = logged.sum(:duration_minutes)
    claimed = logged.where(hours_self_claimed: true).sum(:duration_minutes)
    short = logged.pluck(:body, :duration_minutes).count { |body, m| Journal.written_length(body) < Journal.body_length_needed(m) }
    flagged = WritingCheck.where(journal_id: journals.select(:id)).flagged.exists?
    [
      check("journals", "Has journals", minutes.positive?, "Log journals first. You must have a finished design by this point! Learn more [here]!", doc: "start-here"),
      check("journal_hours", "Every journal has hours", !journals.needing_hours.exists?, "Some journals still need their hours."),
      check("self_claimed", "Hours are backed by tracked time", minutes.zero? || claimed < minutes * SELF_CLAIMED_SHARE, "Most of the hours weren't tracked (huddle or Lapse). Reviewers will look closely at those journals, so make sure they're detailed. If you're unsure, check [this] out.", level: "warn", doc: "journaling"),
      check("journal_length", "Journals explain the work", short.zero?, "#{short} #{short == 1 ? "journal is" : "journals are"} short for the time logged.", level: "warn"),
      check("writing", "Journals are in your own words", !flagged, "A journal was flagged as likely AI-written.", level: "warn")
    ]
  end
end
