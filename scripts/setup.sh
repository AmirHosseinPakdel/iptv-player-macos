#!/usr/bin/env bash
# One-time setup: generates the macOS runner and patches it for networking.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null; then
  echo "Flutter not found. Install it first: https://docs.flutter.dev/get-started/install/macos"
  exit 1
fi

flutter create . --project-name iptv_app --org dev.iptvapp --platforms=macos
flutter pub get

# The macOS sandbox blocks outgoing connections unless this entitlement is set.
for f in macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements; do
  /usr/libexec/PlistBuddy -c "Add :com.apple.security.network.client bool true" "$f" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :com.apple.security.network.client true" "$f"
done

# Many IPTV servers only speak plain HTTP.
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" macos/Runner/Info.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" macos/Runner/Info.plist 2>/dev/null || true

echo
echo "Setup finished. Start the app with:  flutter run -d macos"
