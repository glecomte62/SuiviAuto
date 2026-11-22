#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild test \
  -project SuiviAuto.xcodeproj \
  -scheme SuiviAuto \
  -destination 'platform=macOS' \
  -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli" \
  -quiet "$@"
echo "TESTS OK"
