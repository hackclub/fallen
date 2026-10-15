# /project points at the site: projects are only started there, and PostProjectToSlackJob posts their thread.
class ProjectCommand < SlackBot::Command
  description "Start a project on Fallen"

  def call
    respond(":hammer_and_wrench: Projects start on Fallen: #{SlackMessages.new_project_url}\nOnce it is created, its thread shows up in the journals channel and every reply you post there is a journal.")
  end
end
