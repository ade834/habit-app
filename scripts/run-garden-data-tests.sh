#!/bin/bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$script_dir/../HabitNative/AppLanguage.swift" ]; then
  repo_root="$(cd "$script_dir/.." && pwd)"
elif [ -f "$script_dir/../HabitNative/HabitNative/AppLanguage.swift" ]; then
  repo_root="$(cd "$script_dir/../HabitNative" && pwd)"
else
  repo_root="$(cd "$script_dir/../.." && pwd)/HabitNative"
fi
garden_test_dir="$(mktemp -d)"
trap 'rm -rf "$garden_test_dir"' EXIT
swiftc \
  "$repo_root/HabitNative/AppLanguage.swift" \
  "$repo_root/HabitNative/NativeDatabase.swift" \
  "$repo_root/HabitNative/Goal.swift" \
  "$repo_root/HabitNative/HabitGrowthRules.swift" \
  "$repo_root/HabitNative/SharedHabitSelectionStore.swift" \
  "$repo_root/HabitNative/NativeHabitRepository.swift" \
  "$repo_root/HabitNative/HabitTaskCatalog.swift" \
  "$repo_root/HabitNative/Subscription/SubscriptionManager.swift" \
  "$repo_root/HabitNative/Garden/PosyFloraEngine.swift" \
  "$repo_root/HabitNative/Garden/HabitGardenDatabase.swift" \
  "$script_dir/GardenDataLayerTests.swift" \
  -lsqlite3 -o "$garden_test_dir/garden-data-tests"
"$garden_test_dir/garden-data-tests"
