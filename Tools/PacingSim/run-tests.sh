#!/bin/bash
# Runs the app's XCTest suite on Linux or macOS (engine, data and synth tests; no UI, no simulator).
# Usage: ./run-tests.sh [XCTest filter, e.g. FinaleTests]
set -euo pipefail
cd "$(dirname "$0")"
swift build --build-tests
# The tests load the JSON files through Bundle(for: AppModel.self): next to the test binary on Linux,
# inside the .xctest bundle on macOS.
bin="$(swift build --show-bin-path)"
if [ -d "$bin/PacingSimPackageTests.xctest/Contents" ]; then
    mkdir -p "$bin/PacingSimPackageTests.xctest/Contents/Resources"
    cp ../../GosloRecords/GosloRecords/Resources/*.json "$bin/PacingSimPackageTests.xctest/Contents/Resources/"
else
    cp ../../GosloRecords/GosloRecords/Resources/*.json "$bin/"
fi
swift test --skip-build ${1:+--filter "$1"}
