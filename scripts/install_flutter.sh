#!/usr/bin/env bash
set -euo pipefail

VERSION="${FLUTTER_VERSION:-3.22.1}"
CHANNEL="${FLUTTER_CHANNEL:-stable}"
ARCHIVE="flutter_linux_${VERSION}-${CHANNEL}.tar.xz"
BASE_URL="https://storage.googleapis.com/flutter_infra_release/releases/${CHANNEL}/linux"

REPO_ROOT="$(git rev-parse --show-toplevel)"
INSTALL_DIR="${FLUTTER_HOME:-$REPO_ROOT/.flutter-sdk}"

if [[ -x "$INSTALL_DIR/bin/flutter" ]]; then
  echo "Flutter SDK is already installed at $INSTALL_DIR"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

ARCHIVE_PATH="$TMP_DIR/$ARCHIVE"

echo "Downloading Flutter $VERSION ($CHANNEL channel)..."
curl -L "$BASE_URL/$ARCHIVE" -o "$ARCHIVE_PATH"

echo "Extracting archive..."
tar -xf "$ARCHIVE_PATH" -C "$TMP_DIR"

rm -rf "$INSTALL_DIR"
mkdir -p "$(dirname "$INSTALL_DIR")"
mv "$TMP_DIR/flutter" "$INSTALL_DIR"

echo "Flutter SDK installed to $INSTALL_DIR"
if command -v git >/dev/null 2>&1; then
  git config --global --add safe.directory "$INSTALL_DIR" >/dev/null 2>&1 || true
fi
