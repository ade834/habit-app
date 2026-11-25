#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc "$root/HabitNative/Sync/SyncConflictResolver.swift" "$root/HabitNative/Sync/SyncCloudRecordCodec.swift" "$root/HabitNative/Sync/SyncRevisionStore.swift" "$root/HabitNative/Sync/SyncCoordinator.swift" "$root/scripts/SyncCoordinatorTests.swift" -lsqlite3 -o "$tmp/sync-coordinator-tests"
"$tmp/sync-coordinator-tests"
