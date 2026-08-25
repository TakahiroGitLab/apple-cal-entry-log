#!/bin/bash
#
# Build EntryLog.app and put it in /Applications.
#
# Worth having as its own step: once a copy lives in /Applications,
# rebuilding into build/ alone leaves that copy stale, and running the
# old one while editing the new one is a confusing afternoon.

set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUILT="${ROOT}/build/EntryLog.app"
readonly INSTALLED="/Applications/EntryLog.app"

"${ROOT}/Scripts/make-app.sh" "$@"

if pgrep -x EntryLog > /dev/null; then
    echo "quitting the running copy"
    pkill -x EntryLog
fi

# Replaced rather than copied over: a file left behind by an older
# build would otherwise survive into the new one.
rm -rf "${INSTALLED}"
cp -R "${BUILT}" "${INSTALLED}"

codesign --verify --strict "${INSTALLED}"

echo "installed ${INSTALLED}"
