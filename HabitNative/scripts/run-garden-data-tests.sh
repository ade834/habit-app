#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
garden_test_dir="$(mktemp -d)"
trap 'rm -f "$garden_test_dir/garden-data-tests"; rmdir "$garden_test_dir"' EXIT
swiftc \
  "$repo_root/HabitNative/HabitNative/NativeDatabase.swift" \
  "$repo_root/HabitNative/HabitNative/Goal.swift" \
  "$repo_root/HabitNative/HabitNative/HabitGrowthRules.swift" \
  "$repo_root/HabitNative/HabitNative/SharedHabitSelectionStore.swift" \
  "$repo_root/HabitNative/HabitNative/NativeHabitRepository.swift" \
  "$repo_root/HabitNative/HabitNative/HabitTaskCatalog.swift" \
  "$repo_root/HabitNative/HabitNative/Garden/PosyFloraEngine.swift" \
  "$repo_root/HabitNative/HabitNative/Garden/HabitGardenDatabase.swift" \
  "$repo_root/HabitNative/scripts/GardenDataLayerTests.swift" \
  -lsqlite3 -o "$garden_test_dir/garden-data-tests"
"$garden_test_dir/garden-data-tests"
