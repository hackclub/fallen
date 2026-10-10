# Runs Slack Events API callbacks off the request cycle (Slack wants a 200 within 3 seconds).
class SlackEventJob < ApplicationJob
  queue_as :slack

  def perform(body)
    SlackBot.handle(:event, body)
  end
end
