#!/bin/bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$script_dir/../HabitNative/AppLanguage.swift" ]; then
  root="$(cd "$script_dir/.." && pwd)"
elif [ -f "$script_dir/../HabitNative/HabitNative/AppLanguage.swift" ]; then
  root="$(cd "$script_dir/../HabitNative" && pwd)"
else
  root="$(cd "$script_dir/../.." && pwd)/HabitNative"
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc "$root/HabitNative/AppLanguage.swift" "$root/HabitNative/NativeDatabase.swift" "$root/HabitNative/Goal.swift" \
  "$root/HabitNative/HabitGrowthRules.swift" "$root/HabitNative/SharedHabitSelectionStore.swift" \
  "$root/HabitNative/Subscription/SubscriptionManager.swift" \
  "$root/HabitNative/NativeHabitRepository.swift" "$root/HabitNative/HabitTaskCatalog.swift" \
  "$root/HabitNative/BadgeProgressStore.swift" "$script_dir/BadgeProgressTests.swift" \
  -lsqlite3 -o "$tmp/badge-tests"
"$tmp/badge-tests"
