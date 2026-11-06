#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
BUILD="$ROOT/build/local"
if [[ "$MODE" != "--build-only" ]]; then pkill -x Bushel || true; fi
xcodebuild -project "$ROOT/Bushel.xcodeproj" -scheme Bushel -destination 'platform=macOS' -derivedDataPath "$BUILD" CODE_SIGNING_ALLOWED=NO build
APP="$BUILD/Build/Products/Debug/Bushel.app"
case "$MODE" in
  --build-only) exit 0 ;;
  --debug) exec lldb -- "$APP/Contents/MacOS/Bushel" ;;
  *) open -n "$APP" ;;
esac
if [[ "$MODE" == "--verify" ]]; then sleep 1; pgrep -x Bushel; fi
if [[ "$MODE" == "--logs" || "$MODE" == "--telemetry" ]]; then
  exec log stream --info --predicate 'process == "Bushel"'
fi
