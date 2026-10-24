# frozen_string_literal: true

module Mcp
  # Runs one tool call: opens the McpAction row first so its id exists, runs the tool as the admin with PaperTrail
  # stamping that id on every version it writes, then closes the row with the outcome whatever happened. No
  # transaction wraps the tool, as none wraps an admin controller action: a job enqueued inside one could run before
  # the rows it needs are committed.
  module Invoke
    # Errors that are the caller's to fix, answered with their message. Anything else is a crash: reported, and
    # answered without its message, which can carry SQL or internals.
    SOFT_ERRORS = [ ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError, KeyError, Mcp::Refused ].freeze
    # The most a tool may hand back, about twelve thousand tokens. Past it the call stands but its result is replaced
    # by the size of each section, so the model asks for a page instead.
    RESPONSE_LIMIT = 48_000

    module_function

    def call(tool, args, server_context)
      ctx = Context.new(server_context)
      action = McpAction.create!(user: ctx.admin, admin_token: ctx.token, tool: tool.tool_name, kind: tool.kind_value.to_s,
                                 status: "running", arguments: Scrub.arguments(args))
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      payload, status, error = nil, "ok", nil
      begin
        Current.user = Current.true_user = ctx.admin
        info = { source: "mcp:#{tool.tool_name}", mcp_action_id: action.id }
        payload = PaperTrail.request(whodunnit: ctx.admin.id.to_s, controller_info: info) { tool.run(ctx, **args.to_h.symbolize_keys) }
      rescue StandardError => e
        status, error = outcome(e, action)
      ensure
        close(action, tool, status:, error:, started:, payload:, subject: ctx.subject)
      end
      respond(action, status:, error:, payload:)
    end

    def respond(action, status:, error:, payload:)
      ok = status == "ok"
      body = { ok:, mcp_action_id: action.id }
      ok ? body[:result] = payload : body[:error] = error
      body = body.as_json
      text = JSON.pretty_generate(body)
      text, body = too_large(body, text, action) if text.bytesize > RESPONSE_LIMIT
      MCP::Tool::Response.new([ { type: "text", text: } ], structured_content: body, error: !ok)
    end

    def too_large(body, text, action)
      result = body["result"]
      sections = result.is_a?(Hash) ? result.transform_values { JSON.generate(it).bytesize }.sort_by { -it.last }.to_h : {}
      body = body.except("result").merge(
        "too_large" => { "bytes" => text.bytesize, "limit" => RESPONSE_LIMIT, "sections" => sections },
        "hint" => "The result was withheld because it is too long. Ask for a smaller page or a narrower filter."
      )
      action.update_columns(error: "response of #{text.bytesize} bytes withheld (limit #{RESPONSE_LIMIT})")
      [ JSON.pretty_generate(body), body ]
    end

    def outcome(error, action)
      case error
      when Pundit::NotAuthorizedError then [ "refused", "Not allowed." ]
      when ActiveRecord::RecordNotFound then [ "error", "Not found." ]
      when *SOFT_ERRORS then [ "error", error.message ]
      else
        Rails.error.report(error, handled: true, context: { mcp_action_id: action.id, tool: action.tool })
        [ "error", "Something went wrong (#{error.class.name}). It has been reported." ]
      end
    end

    def close(action, tool, status:, error:, started:, payload:, subject:)
      duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      action.update_columns(status:, error:, duration_ms: duration, updated_at: Time.current,
                            result: status == "ok" ? Scrub.result(payload, write: tool.write?) : nil,
                            subject_type: subject&.class&.base_class&.name, subject_id: subject&.id)
    end
  end
end
