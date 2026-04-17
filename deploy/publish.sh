#!/usr/bin/env bash
set -euo pipefail

##############################################################################
##  SignalDeck Landing Page — Publish Built Static Files
##
##  Usage:
##    ./deploy/publish.sh <user@host> [remote-public-dir]
##
##  Example:
##    ./deploy/publish.sh root@example.com
##    ./deploy/publish.sh deploy@example.com /var/www/cypress-dashboard-site/public
##
##  This script runs the local build, then rsyncs ./public/ to the server.
##############################################################################

if [[ $# -lt 1 ]]; then
    echo "Usage: ./deploy/publish.sh <user@host> [remote-public-dir]" >&2
    exit 1
fi

TARGET="${1}"
REMOTE_DIR="${2:-/var/www/cypress-dashboard-site/public}"

echo "→ Building site locally..."
npm run build

echo "→ Publishing ./public to ${TARGET}:${REMOTE_DIR}/"
rsync -av --delete ./public/ "${TARGET}:${REMOTE_DIR}/"

echo "✓ Publish complete"
