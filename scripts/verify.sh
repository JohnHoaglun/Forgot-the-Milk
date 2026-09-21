#!/usr/bin/env bash
#
# Canonical verification entry point for the Forgot the Milk project.
#
# Builds the app and runs the deterministic unit-test and UI-test suites on
# an iOS simulator. Xcode 26 runs UI tests on parallel simulator clones and
# a wedged clone can hang the phase indefinitely (xcodebuild applies no test
# timeout), so the UI phase runs under a watchdog and, if it fails or
# times out, is retried once on an erased simulator.
#
# Override the simulator by passing a destination string as the first
# argument, e.g.:
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
unit_test_target="Forgot the MilkTests"
ui_test_target="Forgot the MilkUITests"
ui_timeout_minutes=30

echo "Project:     ${project}"
echo "Scheme:      ${scheme}"
echo "Destination: ${destination}"
echo

dest_name="$(sed -n 's/^platform=iOS Simulator,name=\([^,]*\),.*/\1/p' <<< "$destination")"
dest_os="$(sed -n 's/^.*OS=\([0-9.]*\)$/\1/p' <<< "$destination")"
dest_udid="$(python3 - "$dest_name" "$dest_os" <<'PY'
import json, subprocess, sys

name, os_version = sys.argv[1], sys.argv[2]
data = json.loads(subprocess.run(
    ["xcrun", "simctl", "list", "devices", "available", "--json"],
    capture_output=True, text=True, check=True).stdout)
runtime = "com.apple.CoreSimulator.SimRuntime.iOS-" + os_version.replace(".", "-")
for device in data["devices"].get(runtime, []):
    if device["name"] == name:
        print(device["udid"])
        raise SystemExit
raise SystemExit("no available simulator named %r on iOS %s" % (name, os_version))
PY
)"

echo "Simulator:   ${dest_name} (iOS ${dest_os}, ${dest_udid})"
echo

build_app() {
    echo "==> Building (simulator)"
    xcodebuild \
        -project "${project}" \
        -scheme "${scheme}" \
        -destination "${destination}" \
        -derivedDataPath "${derived_data_path}" \
        build
}

run_unit_tests() {
    echo
    echo "==> Running unit tests (simulator)"
    xcodebuild \
        -project "${project}" \
        -scheme "${scheme}" \
        -destination "${destination}" \
        -derivedDataPath "${derived_data_path}" \
        -only-testing:"${unit_test_target}" \
        test
}

run_ui_tests() {
    local attempt=1
    while true; do
        echo
        echo "==> Running UI tests (simulator, attempt ${attempt}, watchdog ${ui_timeout_minutes}m)"
        xcodebuild \
            -project "${project}" \
            -scheme "${scheme}" \
            -destination "${destination}" \
            -derivedDataPath "${derived_data_path}" \
            -only-testing:"${ui_test_target}" \
            test &
        local xcode_pid=$!
        (
            sleep "$((ui_timeout_minutes * 60))"
            echo "==> UI test phase exceeded ${ui_timeout_minutes} minutes; killing"
            kill -TERM "${xcode_pid}" 2>/dev/null
            sleep 5
            kill -KILL "${xcode_pid}" 2>/dev/null
        ) &
        local watchdog_pid=$!
        set +e
        wait "${xcode_pid}"
        local status=$?
        set -e
        kill "${watchdog_pid}" 2>/dev/null
        wait "${watchdog_pid}" 2>/dev/null || true
        if [ "${status}" -eq 0 ]; then
            return 0
        fi
        if [ "${attempt}" -ge 2 ]; then
            return "${status}"
        fi
        echo
        echo "==> UI test phase failed (attempt 1); erasing simulator and retrying"
        xcrun simctl shutdown all
        xcrun simctl erase "${dest_udid}"
        xcrun simctl boot "${dest_udid}"
        attempt=2
    done
}

build_app
run_unit_tests
run_ui_tests

echo
echo "verify: OK — build succeeded and unit + UI tests passed."
