#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc "$root/HabitNative/Sync/SyncConflictResolver.swift" "$root/HabitNative/Sync/SyncReconciliation.swift" "$root/scripts/SyncReconciliationTests.swift" -o "$tmp/sync-reconciliation-tests"
"$tmp/sync-reconciliation-tests"
