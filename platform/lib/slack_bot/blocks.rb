# frozen_string_literal: true

module SlackBot
  # Small Block Kit builders. Everything returns plain hashes you can mix with hand-written blocks.
  #
  #   blocks = [
  #     header("Deploys"),
  #     section("*Production* is healthy", accessory: button("Rollback", "rollback", value: "prod", style: "danger")),
  #     divider,
  #     context("Updated just now")
  #   ]
  module Blocks
    module_function

    def mrkdwn(text) = { type: "mrkdwn", text: text.to_s }
    def plain(text, emoji: true) = { type: "plain_text", text: text.to_s, emoji: emoji }

    def header(text) = { type: "header", text: plain(text) }
    def divider = { type: "divider" }

    def section(text = nil, fields: nil, accessory: nil, block_id: nil)
      {
        type: "section",
        text: text && mrkdwn(text),
        fields: fields&.map { |f| f.is_a?(Hash) ? f : mrkdwn(f) },
        accessory: accessory,
        block_id: block_id
      }.compact
    end

    def context(*elements)
      { type: "context", elements: elements.flatten.map { |e| e.is_a?(Hash) ? e : mrkdwn(e) } }
    end

    def actions(*elements, block_id: nil) = { type: "actions", elements: elements.flatten, block_id: block_id }.compact

    def image(url, alt_text, title: nil)
      { type: "image", image_url: url, alt_text: alt_text, title: title && plain(title) }.compact
    end

    def button(text, action_id, value: nil, style: nil, url: nil, confirm: nil)
      { type: "button", text: plain(text), action_id: action_id, value: value, style: style, url: url, confirm: confirm }.compact
    end

    def confirm(title, text, confirm: "Yes", deny: "Cancel", style: nil)
      { title: plain(title), text: mrkdwn(text), confirm: plain(confirm), deny: plain(deny), style: style }.compact
    end

    def option(text, value) = { text: plain(text), value: value.to_s }

    def static_select(action_id, options, placeholder: "Select", initial: nil)
      {
        type: "static_select",
        action_id: action_id,
        placeholder: plain(placeholder),
        options: options.map { |o| o.is_a?(Hash) ? o : option(*o) },
        initial_option: initial
      }.compact
    end

    def radio_buttons(action_id, options, initial: nil)
      { type: "radio_buttons", action_id: action_id, options: options, initial_option: initial }.compact
    end

    # Up to 100 options; Slack reads the picked ones back as `selected_options`.
    def multi_static_select(action_id, options, placeholder: "Select", initial: nil)
      { type: "multi_static_select", action_id: action_id, placeholder: plain(placeholder), options: options, initial_options: initial.presence }.compact
    end

    def checkboxes(action_id, options, initial: nil)
      { type: "checkboxes", action_id: action_id, options: options, initial_options: initial.presence }.compact
    end

    def plain_text_input(action_id, placeholder: nil, multiline: false, initial_value: nil, max_length: nil)
      {
        type: "plain_text_input",
        action_id: action_id,
        placeholder: placeholder && plain(placeholder),
        multiline: multiline,
        initial_value: initial_value,
        max_length: max_length
      }.compact
    end

    def input(label, element, block_id:, optional: false, hint: nil)
      { type: "input", block_id: block_id, label: plain(label), element: element, optional: optional, hint: hint && plain(hint) }.compact
    end

    def modal(title, blocks, callback_id:, submit: "Submit", close: "Cancel", private_metadata: nil, notify_on_close: nil)
      {
        type: "modal",
        callback_id: callback_id,
        title: plain(title),
        submit: submit && plain(submit),
        close: plain(close),
        blocks: blocks,
        private_metadata: private_metadata,
        notify_on_close: notify_on_close
      }.compact
    end
  end
end
