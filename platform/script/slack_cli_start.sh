#!/usr/bin/env sh
# `slack run` calls this with SLACK_BOT_TOKEN and SLACK_APP_TOKEN set. Saves them to .env.development
# (so Rails and the worker see the same app) and runs the Socket Mode bridge.
set -e
cd "$(dirname "$0")/.."

ENV_FILE=.env.development
touch "$ENV_FILE"

put() {
  key=$1; value=$2
  if grep -q "^$key=" "$ENV_FILE"; then
    sed -i "s|^$key=.*|$key=$value|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

put SLACK_BOT_TOKEN "$SLACK_BOT_TOKEN"
put SLACK_APP_TOKEN "$SLACK_APP_TOKEN"
# Socket Mode never sees Slack's real signature: the bridge signs what it forwards with whatever secret Rails has.
if ! grep -q "^SLACK_SIGNING_SECRET=.\+" "$ENV_FILE"; then
  put SLACK_SIGNING_SECRET "$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
fi
export SLACK_SIGNING_SECRET="$(sed -n 's/^SLACK_SIGNING_SECRET=//p' "$ENV_FILE")"

exec node script/slack_socket_mode.mjs
