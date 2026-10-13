# /project opens the "Start a project" modal (ProjectView). The anchor message is posted by PostProjectToSlackJob.
class ProjectCommand < SlackBot::Command
  description "Start a project and track its journals in a thread"

  def call
    return respond(":wave: Sign in first so I know who you are: #{ENV.fetch('APP_URL', 'http://localhost:3000')}") unless user

    open_modal ProjectView.build(channel_id: channel_id)
  end
end
