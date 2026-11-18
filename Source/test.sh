#!/bin/sh
set -eu
cd "$(dirname "$0")"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
xcrun swiftc Recovery.swift RecoveryTests.swift -o "$test_dir/recovery-tests"
"$test_dir/recovery-tests"
