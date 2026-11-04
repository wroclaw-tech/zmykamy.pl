#!/bin/sh
# Writes the apple-app-site-association file with the team ID from the environment.
# Without a team ID the file is skipped, so the site still runs and the path returns 404.
set -eu

if [ -z "${APPLE_TEAM_ID:-}" ]; then
    echo "APPLE_TEAM_ID is not set, skipping apple-app-site-association" >&2
    exit 0
fi

mkdir -p /usr/share/nginx/html/.well-known
envsubst '$APPLE_TEAM_ID' \
    < /etc/nginx/apple-app-site-association.template \
    > /usr/share/nginx/html/.well-known/apple-app-site-association
