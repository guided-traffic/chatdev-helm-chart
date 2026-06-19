#!/usr/bin/env bash
# Local mirror of the CI image build: shallow-clone the pinned ChatDev upstream,
# stage the frontend overlay, build both images locally. No push.
#
# Usage: scripts/build-local.sh [chatdev_ref]   (default: v2.2.0)
set -euo pipefail

REF="${1:-v2.2.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.cache/chatdev-src"

echo "==> ChatDev ref: $REF"
if [ ! -d "$SRC/.git" ]; then
    rm -rf "$SRC"
    git clone --depth 1 --branch "$REF" https://github.com/OpenBMB/ChatDev.git "$SRC"
else
    git -C "$SRC" fetch --depth 1 origin "$REF"
    git -C "$SRC" checkout -q FETCH_HEAD
fi

echo "==> Staging frontend overlay"
cp "$ROOT"/images/frontend/Dockerfile \
   "$ROOT"/images/frontend/nginx.conf \
   "$SRC/frontend/"

echo "==> Building backend image (chatdev-backend:local)"
docker build --target runtime -f "$SRC/Dockerfile" -t chatdev-backend:local "$SRC"

echo "==> Building frontend image (chatdev-frontend:local)"
docker build --target runtime -f "$SRC/frontend/Dockerfile" -t chatdev-frontend:local "$SRC/frontend"

echo "==> Done. Images: chatdev-backend:local, chatdev-frontend:local"
