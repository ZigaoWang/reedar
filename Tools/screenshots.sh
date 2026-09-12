#!/bin/bash
#
# Every screenshot the App Store asks for, from a clean simulator.
#
#   Tools/screenshots.sh
#
# Apple takes one iPhone size and one iPad size and scales the rest, so this
# shoots the two that are required:
#
#   6.9" iPhone   1320 × 2868   (iPhone 17 Pro Max)
#   13"  iPad     2064 × 2752   (iPad Pro 13-inch)
#
# The devices are created fresh each run rather than reused, because a
# simulator remembers its orientation between launches and a landscape iPad
# writes a landscape file that App Store Connect rejects for the portrait slot.
#
# Screens come from the app's own launch arguments — see `-seedSampleData` and
# friends in CaseView — so no tapping is simulated and nothing is staged by
# hand.

set -euo pipefail
cd "$(dirname "$0")/.."

OUT="Store/screenshots"
DERIVED="/tmp/reedar-shots"

IPHONE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
IPAD_TYPE="com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB"
RUNTIME=$(xcrun simctl list runtimes --json \
  | python3 -c 'import json,sys; print([r["identifier"] for r in json.load(sys.stdin)["runtimes"] if r["isAvailable"] and "iOS" in r["name"]][-1])')

# Screen name → launch arguments. The case is the app's own first screen and
# takes no argument beyond the sample data.
SHOTS=(
  "1-case:"
  "2-reed:-openReed"
  "3-lifespan:-openStats"
  "4-archive:-openArchive"
)

mkdir -p "$OUT"

shoot() {
  local label=$1 type=$2 name="Reedar-shots-$1"

  xcrun simctl delete "$name" >/dev/null 2>&1 || true
  local udid
  udid=$(xcrun simctl create "$name" "$type" "$RUNTIME")
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null

  xcodebuild -project Reedar.xcodeproj -scheme Reedar -configuration Release \
    -destination "id=$udid" -derivedDataPath "$DERIVED" \
    build CODE_SIGNING_ALLOWED=NO >/dev/null
  xcrun simctl install "$udid" "$DERIVED/Build/Products/Release-iphonesimulator/Reedar.app"

  # The status bar every Apple screenshot has ever had. Discharging at 100
  # rather than "charged", which draws the green charging bolt.
  xcrun simctl status_bar "$udid" override \
    --time "9:41" --batteryState discharging --batteryLevel 100 \
    --cellularMode notSupported --wifiMode active --wifiBars 3

  for shot in "${SHOTS[@]}"; do
    local screen=${shot%%:*} args=${shot#*:}
    xcrun simctl terminate "$udid" wang.zigao.reedar >/dev/null 2>&1 || true
    # shellcheck disable=SC2086
    # -skipIntro matters: the devices are created fresh every run, so without
    # it the welcome cover is up on every launch and all four screenshots come
    # out as the same welcome screen.
    xcrun simctl launch "$udid" wang.zigao.reedar -skipIntro -seedSampleData $args >/dev/null
    # Long enough for the launch veil to fade and any pushed screen to settle.
    sleep 6
    xcrun simctl io "$udid" screenshot "$OUT/$label-$screen.png" >/dev/null 2>&1
    echo "  $OUT/$label-$screen.png"
  done

  xcrun simctl shutdown "$udid"
  xcrun simctl delete "$udid"
}

echo "iPhone 6.9\":"
shoot iphone "$IPHONE_TYPE"
echo "iPad 13\":"
shoot ipad "$IPAD_TYPE"

echo
echo "Sizes:"
for f in "$OUT"/*.png; do
  printf '  %-34s %s\n' "$(basename "$f")" "$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/ {printf "%s ", $2}')"
done
