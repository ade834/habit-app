#!/bin/bash
# Runs the real UIKit input bridge in a separate, disposable simulator app.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_dir="$(mktemp -d)"
test_id="com.deshiru.typewriter-tests"
simulator_id="${1:-${TYPEWRITER_SIMULATOR_UDID:-}}"
if [[ -z "$simulator_id" ]]; then
  simulator_id="$(xcrun simctl list devices booted -j | python3 -c 'import json,sys; devices=[d["udid"] for group in json.load(sys.stdin)["devices"].values() for d in group if d["state"]=="Booted"]; sys.exit("Pass a simulator UDID when there is not exactly one booted simulator.") if len(devices)!=1 else print(devices[0])')"
fi
cleanup() {
  xcrun simctl uninstall "$simulator_id" "$test_id" >/dev/null 2>&1 || true
  rm -rf "$test_dir"
}
trap cleanup EXIT
mkdir -p "$test_dir/Tests.app"
cat > "$test_dir/Tests.app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.deshiru.typewriter-tests</string>
<key>CFBundleExecutable</key><string>Tests</string><key>CFBundleName</key><string>Typewriter Tests</string>
<key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
<key>CFBundlePackageType</key><string>APPL</string><key>UILaunchScreen</key><dict/>
<key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><false/><key>UISceneConfigurations</key><dict/></dict>
</dict></plist>
PLIST
sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"
cat > "$test_dir/TypewriterTestEnvironment.swift" <<'SWIFT'
import SwiftUI

enum HabitColorTheme {
    case original
    var largeOrbCenterColor: Color { .orange }
    var smallOrbCenterColor: Color { .pink }
}

private struct HabitColorThemeKey: EnvironmentKey {
    static let defaultValue = HabitColorTheme.original
}

extension EnvironmentValues {
    var habitColorTheme: HabitColorTheme {
        get { self[HabitColorThemeKey.self] }
        set { self[HabitColorThemeKey.self] = newValue }
    }
}
SWIFT
xcrun --sdk iphonesimulator swiftc -sdk "$sdk_path" -target "$(uname -m)-apple-ios27.0-simulator" -parse-as-library \
  "$test_dir/TypewriterTestEnvironment.swift" \
  "$repo_root/HabitNative/HabitNative/ReviewTypewriter.swift" \
  "$repo_root/HabitNative/scripts/TypewriterInputTests.swift" -o "$test_dir/Tests.app/Tests"
xcrun simctl install "$simulator_id" "$test_dir/Tests.app"
xcrun simctl launch --console "$simulator_id" "$test_id" > "$test_dir/result.log" 2>&1
cat "$test_dir/result.log"
# simctl may return zero for a process which subsequently traps an assertion.
grep -q 'PASS: per-key pinyin sounds' "$test_dir/result.log"
