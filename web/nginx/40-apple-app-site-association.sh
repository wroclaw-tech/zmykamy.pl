#!/bin/sh
# Writes the apple-app-site-association file with the team ID from the environment.
set -eu

if [ -z "${APPLE_TEAM_ID:-}" ]; then
    echo "APPLE_TEAM_ID is not set" >&2
    exit 1
fi

mkdir -p /usr/share/nginx/html/.well-known
envsubst '$APPLE_TEAM_ID' \
    < /etc/nginx/apple-app-site-association.template \
    > /usr/share/nginx/html/.well-known/apple-app-site-association
