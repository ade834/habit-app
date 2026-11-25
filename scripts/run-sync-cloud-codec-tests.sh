#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftc "$root/HabitNative/Sync/SyncConflictResolver.swift" "$root/HabitNative/Sync/SyncCloudRecordCodec.swift" "$root/scripts/SyncCloudCodecTests.swift" -o "$tmp/sync-cloud-codec-tests"
"$tmp/sync-cloud-codec-tests"
