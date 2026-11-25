#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc "$root/HabitNative/AppLanguage.swift" "$root/HabitNative/NativeDatabase.swift" "$root/HabitNative/Goal.swift" "$root/HabitNative/HabitGrowthRules.swift" "$root/HabitNative/SharedHabitSelectionStore.swift" "$root/HabitNative/NativeHabitRepository.swift" "$root/HabitNative/HabitTaskCatalog.swift" "$root/HabitNative/Sync/SyncDomainCatalog.swift" "$root/HabitNative/Sync/SyncSnapshotReader.swift" "$root/HabitNative/Sync/SyncSnapshotBootstrap.swift" "$root/scripts/SyncBootstrapTests.swift" -lsqlite3 -o "$tmp/sync-bootstrap-tests"
"$tmp/sync-bootstrap-tests"
