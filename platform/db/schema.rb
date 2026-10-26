# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_27_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_days", primary_key: ["user_id", "day"], force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "day", null: false
    t.index ["day"], name: "index_active_days_on_day"
  end

  create_table "active_insights_jobs", force: :cascade do |t|
    t.string "job"
    t.string "queue"
    t.float "db_runtime"
    t.datetime "scheduled_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string "uuid"
    t.float "duration"
    t.float "queue_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["started_at", "duration", "queue_time"], name: "idx_on_started_at_duration_queue_time_010695b74f"
    t.index ["started_at", "duration"], name: "index_active_insights_jobs_on_started_at_and_duration"
    t.index ["started_at"], name: "index_active_insights_jobs_on_started_at"
  end

  create_table "active_insights_requests", force: :cascade do |t|
    t.string "controller"
    t.string "action"
    t.string "format"
    t.string "http_method"
    t.text "path"
    t.integer "status"
    t.float "view_runtime"
    t.float "db_runtime"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string "uuid"
    t.float "duration"
    t.virtual "formatted_controller", type: :string, as: "(((controller)::text || '#'::text) || (action)::text)", stored: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.index ["started_at", "duration"], name: "index_active_insights_requests_on_started_at_and_duration"
    t.index ["started_at", "formatted_controller"], name: "idx_on_started_at_formatted_controller_5d659a01d9"
    t.index ["started_at"], name: "index_active_insights_requests_on_started_at"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "token_digest", null: false
    t.string "token_hint", null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_admin_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_admin_tokens_on_user_id"
  end

  create_table "fallout_invites", primary_key: "digest", id: :string, force: :cascade do |t|
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "huddle_events", force: :cascade do |t|
    t.string "call_id", null: false
    t.string "slack_id", null: false
    t.string "kind", null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.index ["call_id", "slack_id", "occurred_at"], name: "index_huddle_events_on_call_id_and_slack_id_and_occurred_at"
    t.index ["slack_id"], name: "index_huddle_events_on_slack_id"
  end

  create_table "huddle_pauses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.string "end_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ended_at"], name: "index_huddle_pauses_on_ended_at"
    t.index ["user_id", "started_at"], name: "index_huddle_pauses_on_user_id_and_started_at"
    t.index ["user_id"], name: "index_huddle_pauses_one_open_per_user", unique: true, where: "(ended_at IS NULL)"
  end

  create_table "huddle_sessions", force: :cascade do |t|
    t.bigint "huddle_id", null: false
    t.bigint "user_id"
    t.string "slack_id", null: false
    t.datetime "joined_at", null: false
    t.datetime "left_at"
    t.string "mode"
    t.text "goal"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "prompted_at_count"
    t.datetime "last_seen_at"
    t.string "join_source"
    t.string "leave_source"
    t.datetime "screenshare_since"
    t.integer "screenshare_seconds", default: 0, null: false
    t.datetime "camera_since"
    t.integer "camera_seconds", default: 0, null: false
    t.string "dm_channel_id"
    t.string "prompt_dm_ts"
    t.datetime "wrap_up_asked_at"
    t.text "done"
    t.integer "deducted_seconds", default: 0, null: false
    t.index ["huddle_id", "slack_id"], name: "index_huddle_sessions_on_huddle_id_and_slack_id"
    t.index ["huddle_id", "slack_id"], name: "index_huddle_sessions_one_open_per_person", unique: true, where: "(left_at IS NULL)"
    t.index ["left_at"], name: "index_huddle_sessions_on_left_at"
    t.index ["slack_id"], name: "index_huddle_sessions_on_slack_id"
    t.index ["user_id"], name: "index_huddle_sessions_on_user_id"
  end

  create_table "huddles", force: :cascade do |t|
    t.string "call_id", null: false
    t.string "channel_id", null: false
    t.string "thread_ts"
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.datetime "handed_off_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "message_count", default: 0, null: false
    t.string "link"
    t.index ["call_id"], name: "index_huddles_on_call_id", unique: true
    t.index ["ended_at"], name: "index_huddles_on_ended_at"
  end

  create_table "journal_drafts", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.jsonb "parts", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "prompt_url"
    t.datetime "prompt_url_at"
    t.jsonb "timelapse_ids", default: [], null: false
    t.index ["parts"], name: "index_journal_drafts_on_parts", opclass: :jsonb_path_ops, using: :gin
    t.index ["project_id", "user_id"], name: "index_journal_drafts_on_project_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_journal_drafts_on_user_id"
  end

  create_table "journals", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.integer "duration_minutes"
    t.string "source", default: "web", null: false
    t.string "slack_channel_id"
    t.string "slack_ts"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "lapse_url"
    t.jsonb "slack_parts", default: [], null: false
    t.bigint "lapse_timelapse_id"
    t.integer "tracked_minutes"
    t.boolean "hours_self_claimed"
    t.boolean "slack_posted_by_bot", default: false, null: false
    t.index ["created_at"], name: "index_journals_on_created_at"
    t.index ["discarded_at"], name: "index_journals_on_discarded_at"
    t.index ["project_id"], name: "index_journals_needing_hours", where: "((discarded_at IS NULL) AND (duration_minutes IS NULL))"
    t.index ["project_id"], name: "index_journals_on_project_id"
    t.index ["slack_channel_id", "slack_ts"], name: "index_journals_on_slack_channel_id_and_slack_ts", unique: true, where: "(slack_ts IS NOT NULL)"
    t.index ["slack_parts"], name: "index_journals_on_slack_parts", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_journals_on_user_id"
  end

  create_table "lapse_timelapses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "lapse_id", null: false
    t.string "name"
    t.integer "duration_seconds", default: 0, null: false
    t.string "visibility"
    t.string "playback_url"
    t.string "thumbnail_url"
    t.datetime "recorded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "journal_id"
    t.index ["journal_id"], name: "index_lapse_timelapses_on_journal_id"
    t.index ["lapse_id"], name: "index_lapse_timelapses_on_lapse_id", unique: true
    t.index ["recorded_at"], name: "index_lapse_timelapses_on_recorded_at"
    t.index ["user_id"], name: "index_lapse_timelapses_on_user_id"
  end

  create_table "mcp_actions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "admin_token_id", null: false
    t.string "tool", null: false
    t.string "kind", null: false
    t.string "status", null: false
    t.jsonb "arguments", default: {}, null: false
    t.jsonb "result"
    t.string "subject_type"
    t.bigint "subject_id"
    t.integer "duration_ms"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_token_id"], name: "index_mcp_actions_on_admin_token_id"
    t.index ["created_at"], name: "index_mcp_actions_on_created_at"
    t.index ["subject_type", "subject_id"], name: "index_mcp_actions_on_subject_type_and_subject_id"
    t.index ["user_id"], name: "index_mcp_actions_on_user_id"
  end

  create_table "mcp_sql_changes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "admin_token_id", null: false
    t.bigint "reviewer_id"
    t.text "sql", null: false
    t.string "kind", null: false
    t.string "table_name", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "preview", default: {}, null: false
    t.integer "rows_affected"
    t.text "error"
    t.datetime "expires_at", null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_token_id"], name: "index_mcp_sql_changes_on_admin_token_id"
    t.index ["created_at"], name: "index_mcp_sql_changes_on_created_at"
    t.index ["reviewer_id"], name: "index_mcp_sql_changes_on_reviewer_id"
    t.index ["user_id"], name: "index_mcp_sql_changes_on_user_id"
  end

  create_table "privacy_token_uses", primary_key: "jti", id: :text, force: :cascade do |t|
    t.datetime "used_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "project_invites", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.bigint "inviter_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inviter_id"], name: "index_project_invites_on_inviter_id"
    t.index ["project_id", "user_id"], name: "index_project_invites_on_project_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_project_invites_on_user_id"
  end

  create_table "project_members", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "user_id"], name: "index_project_members_on_project_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_project_members_on_user_id"
  end

  create_table "project_transfers", force: :cascade do |t|
    t.string "airtable_id", null: false
    t.bigint "user_id"
    t.bigint "reviewer_id"
    t.bigint "project_id"
    t.string "email", null: false
    t.string "name"
    t.string "project_name"
    t.string "source_url", null: false
    t.string "source"
    t.string "source_ref"
    t.string "fallen_project_url"
    t.integer "claimed_minutes"
    t.string "status", default: "pending", null: false
    t.jsonb "snapshot"
    t.datetime "fetched_at"
    t.text "error"
    t.integer "approved_minutes"
    t.integer "xp"
    t.text "note"
    t.datetime "decided_at"
    t.datetime "submitted_at", null: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "message"
    t.index ["airtable_id"], name: "index_project_transfers_on_airtable_id", unique: true
    t.index ["discarded_at"], name: "index_project_transfers_on_discarded_at"
    t.index ["email"], name: "index_project_transfers_on_email"
    t.index ["project_id"], name: "index_project_transfers_on_project_id"
    t.index ["reviewer_id"], name: "index_project_transfers_on_reviewer_id"
    t.index ["source", "source_ref"], name: "index_project_transfers_on_source_and_source_ref"
    t.index ["source"], name: "index_project_transfers_unfetched", where: "(fetched_at IS NULL)"
    t.index ["status"], name: "index_project_transfers_on_status"
    t.index ["submitted_at"], name: "index_project_transfers_on_submitted_at"
    t.index ["user_id"], name: "index_project_transfers_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "repo_url"
    t.string "demo_url"
    t.string "slack_channel_id"
    t.string "slack_thread_ts"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "approved_at"
    t.boolean "slack_posted_by_bot", default: false, null: false
    t.string "join_token"
    t.index ["discarded_at"], name: "index_projects_on_discarded_at"
    t.index ["join_token"], name: "index_projects_on_join_token", unique: true
    t.index ["slack_channel_id", "slack_thread_ts"], name: "index_projects_on_slack_channel_id_and_slack_thread_ts", unique: true, where: "(slack_thread_ts IS NOT NULL)"
    t.index ["updated_at"], name: "index_projects_on_updated_at"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "time_milestones", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "since", null: false
    t.integer "minutes", null: false
    t.datetime "created_at", null: false
    t.text "done"
    t.datetime "answered_at"
    t.string "dm_channel_id"
    t.string "dm_ts"
    t.index ["user_id", "since", "minutes"], name: "index_time_milestones_on_user_id_and_since_and_minutes", unique: true
  end

  create_table "timer_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "started_at", null: false
    t.datetime "stopped_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "goal"
    t.text "done"
    t.datetime "wrapped_up_at"
    t.integer "deducted_seconds", default: 0, null: false
    t.index ["stopped_at"], name: "index_timer_sessions_on_stopped_at"
    t.index ["user_id", "started_at"], name: "index_timer_sessions_on_user_id_and_started_at"
    t.index ["user_id"], name: "index_timer_sessions_one_running_per_user", unique: true, where: "(stopped_at IS NULL)"
  end

  create_table "users", force: :cascade do |t|
    t.string "hca_id"
    t.string "email", null: false
    t.string "display_name", null: false
    t.string "avatar"
    t.string "slack_id"
    t.string "timezone", default: "UTC", null: false
    t.string "roles", default: [], null: false, array: true
    t.string "verification_status"
    t.boolean "is_adult", default: false, null: false
    t.boolean "is_banned", default: false, null: false
    t.text "hca_token"
    t.datetime "last_seen_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "slack_user_token"
    t.string "slack_user_token_scopes"
    t.string "pet"
    t.integer "xp", default: 0, null: false
    t.decimal "xp_multiplier", precision: 3, scale: 2, default: "1.0", null: false
    t.integer "streak_freezes", default: 3, null: false
    t.datetime "airtable_synced_at"
    t.datetime "hatch_seen_at"
    t.text "lapse_token"
    t.datetime "lapse_synced_at"
    t.jsonb "signup_source", default: {}, null: false
    t.datetime "slack_skipped_at"
    t.datetime "pet_switched_at"
    t.string "soft_signup"
    t.index ["airtable_synced_at"], name: "index_users_on_airtable_synced_at"
    t.index ["created_at"], name: "index_users_on_created_at"
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email"], name: "index_users_on_email"
    t.index ["hca_id"], name: "index_users_on_hca_id", unique: true
    t.index ["last_seen_at"], name: "index_users_on_last_seen_at"
    t.index ["roles"], name: "index_users_on_roles", using: :gin
    t.index ["slack_id"], name: "index_users_on_slack_id"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.jsonb "object_changes"
    t.string "source"
    t.bigint "mcp_action_id"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["mcp_action_id"], name: "index_versions_on_mcp_action_id"
  end

  create_table "writing_checks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "journal_id"
    t.text "body", null: false
    t.string "status", default: "pending", null: false
    t.float "fraction_ai"
    t.float "fraction_ai_assisted"
    t.boolean "insisted", default: false, null: false
    t.string "slack_ts"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "billed", default: true, null: false
    t.index ["journal_id"], name: "index_writing_checks_on_journal_id"
    t.index ["user_id"], name: "index_writing_checks_on_user_id"
  end

  create_table "xp_entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "kind", null: false
    t.integer "amount", null: false
    t.decimal "multiplier", precision: 3, scale: 2
    t.date "day", null: false
    t.string "source_type"
    t.bigint "source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_xp_entries_on_discarded_at"
    t.index ["source_type", "source_id", "kind"], name: "index_xp_entries_on_source_type_and_source_id_and_kind", unique: true, where: "(source_id IS NOT NULL)"
    t.index ["user_id", "day"], name: "index_xp_entries_on_user_id_and_day"
    t.index ["user_id", "kind", "day"], name: "index_xp_entries_on_user_id_and_kind_and_day", unique: true, where: "(source_id IS NULL)"
    t.index ["user_id"], name: "index_xp_entries_on_user_id"
    t.index ["user_id"], name: "index_xp_entries_one_stupendous_per_user", unique: true, where: "((kind)::text = 'stupendous'::text)"
  end

  add_foreign_key "active_days", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_tokens", "users"
  add_foreign_key "huddle_pauses", "users"
  add_foreign_key "huddle_sessions", "huddles"
  add_foreign_key "huddle_sessions", "users"
  add_foreign_key "journal_drafts", "projects"
  add_foreign_key "journal_drafts", "users"
  add_foreign_key "journals", "projects"
  add_foreign_key "journals", "users"
  add_foreign_key "lapse_timelapses", "journals"
  add_foreign_key "lapse_timelapses", "users"
  add_foreign_key "mcp_actions", "admin_tokens"
  add_foreign_key "mcp_actions", "users"
  add_foreign_key "mcp_sql_changes", "admin_tokens"
  add_foreign_key "mcp_sql_changes", "users"
  add_foreign_key "mcp_sql_changes", "users", column: "reviewer_id"
  add_foreign_key "project_invites", "projects"
  add_foreign_key "project_invites", "users"
  add_foreign_key "project_invites", "users", column: "inviter_id"
  add_foreign_key "project_members", "projects"
  add_foreign_key "project_members", "users"
  add_foreign_key "project_transfers", "projects"
  add_foreign_key "project_transfers", "users"
  add_foreign_key "project_transfers", "users", column: "reviewer_id"
  add_foreign_key "projects", "users"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "time_milestones", "users"
  add_foreign_key "timer_sessions", "users"
  add_foreign_key "writing_checks", "journals"
  add_foreign_key "writing_checks", "users"
  add_foreign_key "xp_entries", "users"
end
