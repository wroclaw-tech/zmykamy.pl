#!/usr/bin/env bash
# Builds and tests the app the same way locally and in CI.
#
#   scripts/xcode.sh unit      # unit tests (zmykamy.plTests)
#   scripts/xcode.sh ui        # UI tests (zmykamy.plUITests)
#   scripts/xcode.sh test      # both
#   scripts/xcode.sh release   # Release build for devices, unsigned
#
# Extra arguments go to xcodebuild, e.g. `scripts/xcode.sh unit -only-testing:zmykamy.plTests/PollsStoreTests`.
# Set SIMULATOR to a device name or UDID to override the automatically picked iPhone simulator.
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT=zmykamy.pl.xcodeproj
SCHEME=zmykamy.pl
DERIVED_DATA=${DERIVED_DATA:-build/DerivedData}
RESULTS=${RESULTS:-build/results}

# The newest available iPhone simulator, so the script works whatever runtimes are installed.
pick_simulator() {
    xcrun simctl list devices available --json | python3 -c '
import json, re, sys
devices = json.load(sys.stdin)["devices"]
# Runtime ids look like "...SimRuntime.iOS-27-2", sometimes with a device suffix ("iOS-27-2-iPhone19").
def version(runtime):
    return [int(part) for part in re.search(r"\.iOS-(\d+(?:-\d+)*)", runtime).group(1).split("-")]
iphones = [
    (version(runtime), device["udid"])
    for runtime, list in devices.items() if ".iOS-" in runtime
    for device in list if device["name"].startswith("iPhone")
]
if not iphones:
    sys.exit("No iPhone simulator available")
print(max(iphones)[1])
'
}

run_tests() {
    local name=$1
    shift
    local simulator
    simulator=${SIMULATOR:-$(pick_simulator)}
    rm -rf "$RESULTS/$name.xcresult"
    # Boot up front so a slow simulator start doesn't count against the tests.
    xcrun simctl bootstatus "$simulator" -b >/dev/null
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$simulator" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$RESULTS/$name.xcresult" \
        "$@"
}

command=${1:-test}
shift || true

case $command in
    unit) run_tests unit -only-testing:zmykamy.plTests "$@" ;;
    # Parallel UI testing boots simulator clones, which hang on CI runners. A hung test fails after the allowance.
    ui) run_tests ui -only-testing:zmykamy.plUITests -parallel-testing-enabled NO \
        -test-timeouts-enabled YES -default-test-execution-time-allowance 180 "$@" ;;
    test) run_tests all "$@" ;;
    release)
        xcodebuild build \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration Release \
            -destination "generic/platform=iOS" \
            -derivedDataPath "$DERIVED_DATA" \
            CODE_SIGNING_ALLOWED=NO \
            "$@"
        ;;
    *)
        echo "Unknown command: $command (expected unit, ui, test or release)" >&2
        exit 64
        ;;
esac
