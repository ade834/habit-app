#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

swiftc \
  "$repo_root/HabitNative/HabitNative/NativeDatabase.swift" \
  "$repo_root/HabitNative/HabitNative/Goal.swift" \
  "$repo_root/HabitNative/HabitNative/HabitGrowthRules.swift" \
  "$repo_root/HabitNative/HabitNative/SharedHabitSelectionStore.swift" \
  "$repo_root/HabitNative/HabitNative/NativeHabitRepository.swift" \
  "$repo_root/HabitNative/HabitNative/HabitTaskCatalog.swift" \
  "$repo_root/HabitNative/scripts/NativeDataLayerTests.swift" \
  -lsqlite3 -o "$tmp_dir/native-data-tests"

"$tmp_dir/native-data-tests"
