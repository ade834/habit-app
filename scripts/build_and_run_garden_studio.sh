#!/bin/bash
set -e

DEVICE_ID="50439C55-1ACC-42F5-A4C0-BC071CAFADD9" # iPhone 18 Pro
WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$WORKSPACE_DIR/build_garden_studio"
APP_DIR="$BUILD_DIR/GardenStudioApp.app"

echo "=== 1. 准备构建目录 ==="
rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR"

echo "=== 2. 编译 GardenStudioApp 源码 ==="
xcrun -sdk iphonesimulator swiftc \
  -target arm64-apple-ios27.0-simulator \
  -O \
  "$WORKSPACE_DIR/HabitNative/GardenStudioApp/GardenStudioApp.swift" \
  "$WORKSPACE_DIR/HabitNative/HabitNative/Garden/GardenStudioView.swift" \
  "$WORKSPACE_DIR/HabitNative/HabitNative/Garden/PosyCinematicDoorIntroView.swift" \
  "$WORKSPACE_DIR/HabitNative/HabitNative/Garden/PosyFloraEngine.swift" \
  "$WORKSPACE_DIR/HabitNative/HabitNative/Garden/PosyFlowerBloomCanvas.swift" \
  "$WORKSPACE_DIR/HabitNative/HabitNative/Garden/PosyGardenCreatures.swift" \
  "$WORKSPACE_DIR/HabitNative/HabitNative/Garden/PosyInteractiveStemFlower.swift" \
  -o "$APP_DIR/GardenStudioApp"

echo "=== 3. 生成 App Bundle ==="
cp "$WORKSPACE_DIR/HabitNative/GardenStudioApp/Info.plist" "$APP_DIR/Info.plist"
echo -n "APPL????" > "$APP_DIR/PkgInfo"

echo "=== 4. 签名 ==="
/usr/bin/codesign --force --sign - --timestamp=none "$APP_DIR"

echo "=== 4.5 确保 iPhone 18 Pro 已开机 ==="
STATUS=$(xcrun simctl list devices | grep "$DEVICE_ID" | grep -o "Booted" || true)
if [ "$STATUS" != "Booted" ]; then
  echo "Booting iPhone 18 Pro ($DEVICE_ID)..."
  xcrun simctl boot "$DEVICE_ID" || true
  sleep 3
fi

echo "=== 5. 安装至 iPhone 18 Pro 模拟器 ==="
xcrun simctl install "$DEVICE_ID" "$APP_DIR"

echo "=== 6. 启动应用 ==="
killall -9 GardenStudioApp 2>/dev/null || true
xcrun simctl terminate "$DEVICE_ID" com.deshiru.habitnative.gardenstudio || true
sleep 0.6
xcrun simctl launch --terminate-running-process "$DEVICE_ID" com.deshiru.habitnative.gardenstudio

echo "=== 7. 唤起 Device Hub 前台 ==="
open -a "/Applications/Xcode.app/Contents/Applications/DeviceHub.app"

echo "=== 8. 捕获多阶段开场漫游截图 ==="
sleep 1.20
DISTANT_SHOT="/Users/deshiru/.gemini/antigravity/brain/481a80d2-5d4f-4a63-a79f-cdfbe42f06df/door_intro_distant.png"
xcrun simctl io "$DEVICE_ID" screenshot "$DISTANT_SHOT"
echo "Saved distant door scene to $DISTANT_SHOT"

sleep 1.40
APPROACH_SHOT="/Users/deshiru/.gemini/antigravity/brain/481a80d2-5d4f-4a63-a79f-cdfbe42f06df/door_intro_approaching.png"
xcrun simctl io "$DEVICE_ID" screenshot "$APPROACH_SHOT"
echo "Saved approaching door scene to $APPROACH_SHOT"

sleep 0.80
SWEEP_SHOT="/Users/deshiru/.gemini/antigravity/brain/481a80d2-5d4f-4a63-a79f-cdfbe42f06df/door_intro_frame_sweep.png"
xcrun simctl io "$DEVICE_ID" screenshot "$SWEEP_SHOT"
echo "Saved door frame sweeping scene with gradient Gaussian blur to $SWEEP_SHOT"

sleep 0.80
BLOOM_SHOT="/Users/deshiru/.gemini/antigravity/brain/481a80d2-5d4f-4a63-a79f-cdfbe42f06df/door_intro_white_bloom.png"
xcrun simctl io "$DEVICE_ID" screenshot "$BLOOM_SHOT"
echo "Saved white bloom transition to $BLOOM_SHOT"

sleep 1.00
REVEAL_SHOT="/Users/deshiru/.gemini/antigravity/brain/481a80d2-5d4f-4a63-a79f-cdfbe42f06df/door_intro_plants_revealing.png"
xcrun simctl io "$DEVICE_ID" screenshot "$REVEAL_SHOT"
echo "Saved plants revealing from bloom to $REVEAL_SHOT"

sleep 1.60
FINAL_SHOT="/Users/deshiru/.gemini/antigravity/brain/481a80d2-5d4f-4a63-a79f-cdfbe42f06df/garden_studio_screenshot.png"
xcrun simctl io "$DEVICE_ID" screenshot "$FINAL_SHOT"
echo "Saved final full-page screenshot to $FINAL_SHOT"
