#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc "$root/HabitNative/Sync/SyncPreferenceReader.swift" "$root/scripts/SyncPreferenceTests.swift" -o "$tmp/sync-preference-tests"
"$tmp/sync-preference-tests"
