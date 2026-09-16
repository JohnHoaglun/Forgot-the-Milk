#!/usr/bin/env bash
#
# Canonical verification entry point for the Forgot the Milk project.
#
# Builds the app and runs the deterministic unit-test suite on an iOS
# simulator. Override the simulator by passing a destination string as the
# first argument, e.g.:
#
#   scripts/verify.sh "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5"
#
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

project="Forgot the Milk.xcodeproj"
scheme="Forgot the Milk"
destination="${1:-platform=iOS Simulator,name=iPhone 17,OS=27.0}"
derived_data_path="${TMPDIR:-/tmp}/forgot-the-milk-verify"

echo "Project:     ${project}"
echo "Scheme:      ${scheme}"
echo "Destination: ${destination}"
echo

echo "==> Building (simulator)"
xcodebuild \
  -project "${project}" \
  -scheme "${scheme}" \
  -destination "${destination}" \
  -derivedDataPath "${derived_data_path}" \
  build

echo
echo "==> Running tests (simulator)"
xcodebuild \
  -project "${project}" \
  -scheme "${scheme}" \
  -destination "${destination}" \
  -derivedDataPath "${derived_data_path}" \
  test

echo
echo "verify: OK — build succeeded and tests passed."
