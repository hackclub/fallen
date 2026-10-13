# The "Start a project" modal, opened by /project or by the nudge under a top-level message
# (ProjectFromMessageAction). With an anchor message the person's own post becomes the thread;
# without one the bot posts the anchor for them.
class ProjectView < SlackBot::View
  extend SlackBot::Blocks

  def self.build(channel_id:, anchor_ts: nil, response_url: nil, initial_description: nil)
    modal(
      "Start a project",
      [
        input("What are you building?", plain_text_input("title", placeholder: "A short, memorable name", max_length: 120), block_id: "title"),
        input("Tell us a bit more", plain_text_input("description", multiline: true, initial_value: initial_description, max_length: 2000), block_id: "description", optional: true),
        input("Repo", plain_text_input("repo_url", placeholder: "https://github.com/..."), block_id: "repo_url", optional: true),
        context(anchor_ts ? "Your message becomes the project thread. Reply to it with each session's progress." : "I'll post the project in the journals channel. Reply in that thread with each session's progress.")
      ],
      callback_id: "project",
      submit: "Start",
      private_metadata: { channel_id: channel_id, anchor_ts: anchor_ts, response_url: response_url }.compact.to_json
    )
  end

  def call
    return close unless user

    metadata = JSON.parse(private_metadata.to_s) rescue {}
    anchor_ts = metadata["anchor_ts"].presence
    project = user.projects.build(title: values["title"].to_s.strip, description: values["description"].to_s.strip.presence, repo_url: values["repo_url"].to_s.strip.presence)
    if anchor_ts
      project.slack_channel_id = metadata["channel_id"]
      project.slack_thread_ts = anchor_ts
    end

    unless project.save
      field = project.errors.attribute_names.first.to_s
      field = "title" unless field.in?(%w[title description repo_url])
      return errors(field.to_sym => project.errors.full_messages.first)
    end

    if anchor_ts
      say(":notebook_with_decorative_cover: Tracking *#{SlackMessages.escape(project.title)}*. Every reply you post here is a journal. <#{SlackMessages.project_url(project)}|Open on Fallen>",
          channel: metadata["channel_id"], thread_ts: anchor_ts)
      SlackBot::Reactions.add(metadata["channel_id"], anchor_ts, "notebook_with_decorative_cover")
    else
      PostProjectToSlackJob.perform_later(project)
    end

    dismiss_nudge(metadata["response_url"])
    ephemeral(":tada: *#{SlackMessages.escape(project.title)}* started. <#{SlackMessages.project_url(project)}|Open on Fallen>", channel: metadata["channel_id"]) if metadata["channel_id"].present? && !anchor_ts
    close
  end

  private

  def dismiss_nudge(response_url)
    return if response_url.blank?

    Faraday.post(response_url, { delete_original: true }.to_json, "Content-Type" => "application/json")
  rescue Faraday::Error
    nil
  end
end
