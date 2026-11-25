#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc "$root/HabitNative/Sync/SyncConflictResolver.swift" "$root/scripts/SyncConflictTests.swift" -o "$tmp/sync-conflict-tests"
"$tmp/sync-conflict-tests"
