#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
FLUTTER_HOME="${FLUTTER_HOME:-$REPO_ROOT/.flutter-sdk}"

if [[ ! -x "$FLUTTER_HOME/bin/flutter" ]]; then
  "$REPO_ROOT/scripts/install_flutter.sh"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"

pushd "$REPO_ROOT/mobile" > /dev/null
flutter pub get
flutter test "$@"
popd > /dev/null
