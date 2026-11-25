namespace :dev do
  # Design reviewers' decisions waiting for an admin (SubmissionReview#propose), to try /admin/sign-offs locally.
  # Each run adds three more: an approval with a deflated journal, a return, and a plain approval. Sign in as
  # admin@example.com (db:seed) to sign them off, or as reviewer@example.com to see them from the reviewer's side.
  desc "Development only: add design submissions held for an admin to sign off"
  task sign_offs: :environment do
    abort "Development only" unless Rails.env.development?

    admin = User.find_or_initialize_by(hca_id: "dev_admin")
    admin.assign_attributes(email: "admin@example.com", display_name: "Dev Admin", roles: %w[admin user]) if admin.new_record?
    admin.save!
    reviewer = User.find_or_initialize_by(hca_id: "dev_reviewer")
    reviewer.assign_attributes(email: "reviewer@example.com", display_name: "Dev Reviewer", roles: %w[user design_reviewer])
    reviewer.save!

    run = Project.where("title LIKE ?", "Sign-off test %").count / 3 + 1
    rubric = Submission::RUBRIC.keys.index_with { "yes" }
    cases = [
      { title: "Macropad", verdict: "approved", deflate: true, internal: "Solid PCB; one journal padded with idle time.", feedback: "" },
      { title: "Plant monitor", verdict: "returned", deflate: false, internal: "No gerbers in the repo.", feedback: "Add your gerbers and a photo of the routed board, then send it again." },
      { title: "Split keyboard", verdict: "approved", deflate: false, internal: "Everything checks out.", feedback: "Great work!" }
    ]

    cases.each_with_index do |c, i|
      builder = User.find_or_initialize_by(hca_id: "dev_builder_#{run}_#{i}")
      builder.assign_attributes(email: "builder#{run}-#{i}@example.com", display_name: "Builder #{run}.#{i + 1}", roles: %w[user])
      builder.save!

      project = builder.projects.create!(title: "Sign-off test #{run}: #{c[:title]}", description: "A #{c[:title].downcase}, made to try signing off.")
      [ [ "Sketched the schematic and picked parts.", 90 ], [ "Routed the PCB and ran DRC; fixed two clearance errors.", 120 ],
        [ "Wrote the firmware and tested every input.", 75 ] ].each_with_index do |(body, minutes), n|
        # Past Journal's evidence checks (length, images): this is about the review, not the journal.
        project.journals.new(user: builder, body:, duration_minutes: minutes, created_at: (3 - n).days.ago).save!(validate: false)
      end

      snapshot = RepoSnapshot.create!(project:, user: builder, url: "https://github.com/someone/#{c[:title].parameterize}", status: "done", fetched_at: Time.current,
        branch: "main", commit_sha: "a" * 40, readme_path: "README.md", readme: "# #{c[:title]}\n\nA board I made.",
        tree: %w[README.md board.kicad_pcb board.kicad_sch board.kicad_pro gerbers.zip bom.csv].map { { "path" => it, "type" => "blob" } },
        bom_path: "bom.csv", bom_csv: "Part,Qty,Price,Link\nRP2040,2,$1.00,https://lcsc.com/a\n")
      png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: "render.png", content_type: "image/png", metadata: { Journal::UPLOADER_KEY => builder.id })
      items = [ { kind: "part", name: "RP2040", quantity: 2, unit_cents: 100, total_cents: 200, link: "https://lcsc.com/a", owned: false },
                { kind: "part", name: "PCB from JLCPCB", quantity: 5, unit_cents: 240, total_cents: 1_200, link: "https://jlcpcb.com", owned: false },
                { kind: "shipping", name: "Shipping", quantity: 1, total_cents: 500 } ]
      submission = Submission.submit(project:, user: builder, snapshot:, made_with: %w[pcb], note: nil, items:, screenshots: [ blob.signed_id ])
      abort "Couldn't submit #{project.title}: #{submission.errors.full_messages.to_sentence}" unless submission.persisted?

      journals = SubmissionReview.journals_for(submission).order(:created_at).to_a
      calls = journals.to_h { [ it.public_id, { "approved_minutes" => it.duration_minutes } ] }
      if c[:deflate]
        calls[journals.second.public_id] = { "approved_minutes" => 60, "reason" => JournalReview::REASONS.first, "note" => "The video shows about an hour of routing." }
      end
      review = SubmissionReview.new(submission, reviewer:, verdict: c[:verdict], feedback: c[:feedback], internal_reason: c[:internal], rubric:, journals: calls)
      abort "Couldn't propose #{project.title}: #{review.errors.full_messages.to_sentence}" unless review.save && review.proposed?

      puts "Held: #{project.title} (#{c[:verdict]}) #{submission.public_id}"
    end

    puts "\nSign off as the admin:   http://localhost:3000/dev/sign_in_as/admin@example.com  then  http://localhost:3000/admin/sign-offs"
    puts "See it as the reviewer:  http://localhost:3000/dev/sign_in_as/reviewer@example.com  then  http://localhost:3000/admin/reviews?tab=sign_off"
  end
end
