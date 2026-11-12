#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build/tests
ARCH="$(uname -m)"

swiftc -O -parse-as-library \
  -target "$ARCH-apple-macos14.0" \
  Sources/Services/Defaults.swift \
  Sources/Services/BeszelParsing.swift \
  Tests/PureLogicTests.swift \
  -o build/tests/islet-tests

./build/tests/islet-tests
