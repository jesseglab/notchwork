#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
TEST_ROOT=$(mktemp -d /private/tmp/notchwork-tests.XXXXXX)
export CLANG_MODULE_CACHE_PATH="$TEST_ROOT/module-cache"
export SWIFT_MODULE_CACHE_PATH="$TEST_ROOT/module-cache"
trap 'rm -rf "$TEST_ROOT"' EXIT
cp Package.swift "$TEST_ROOT/"
ditto --norsrc Sources "$TEST_ROOT/Sources"
ditto --norsrc Tests "$TEST_ROOT/Tests"
swift test --package-path "$TEST_ROOT" --scratch-path "$TEST_ROOT/build" "$@"
