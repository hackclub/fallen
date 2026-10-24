# The admin MCP server (McpController, docs/mcp.md). A tool that raises is answered by Mcp::Invoke; what reaches the
# gem's reporter is a failure of the protocol layer itself.
MCP.configure do |config|
  config.exception_reporter = lambda do |exception, context|
    Rails.error.report(exception, handled: true, context: { mcp: context.to_h.except(:request) })
  end
end
