#!/bin/bash
# Runs the app's XCTest suite on Linux (engine, data and synth tests; no UI).
# Usage: ./run-tests.sh [XCTest filter, e.g. FinaleTests]
set -euo pipefail
cd "$(dirname "$0")"
swift build --build-tests
# The tests load the JSON files through Bundle(for: AppModel.self), i.e. next to the test binary on Linux.
cp ../../GosloRecords/GosloRecords/Resources/*.json "$(swift build --show-bin-path)/"
swift test --skip-build ${1:+--filter "$1"}
