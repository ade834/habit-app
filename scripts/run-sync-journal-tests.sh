#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc "$root/HabitNative/Sync/SyncConflictResolver.swift" "$root/HabitNative/Sync/SyncCloudRecordCodec.swift" "$root/HabitNative/Sync/SyncRevisionStore.swift" "$root/scripts/SyncRevisionStoreTests.swift" -lsqlite3 -o "$tmp/sync-journal-tests"
"$tmp/sync-journal-tests"
