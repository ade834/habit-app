#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc "$root/HabitNative/AppLanguage.swift" "$root/HabitNative/NativeDatabase.swift" "$root/HabitNative/Goal.swift" "$root/HabitNative/HabitGrowthRules.swift" "$root/HabitNative/SharedHabitSelectionStore.swift" "$root/HabitNative/NativeHabitRepository.swift" "$root/HabitNative/HabitTaskCatalog.swift" "$root/HabitNative/Sync/SyncDomainCatalog.swift" "$root/scripts/SyncDomainCatalogTests.swift" -lsqlite3 -o "$tmp/sync-domain-tests"
"$tmp/sync-domain-tests"
