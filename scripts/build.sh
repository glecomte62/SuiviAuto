#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild build \
  -project SuiviAuto.xcodeproj \
  -scheme SuiviAuto \
  -configuration "${CONFIGURATION:-Debug}" \
  -destination 'platform=macOS' \
  -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli" \
  -quiet
echo "BUILD OK: $HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli/Build/Products/${CONFIGURATION:-Debug}/SuiviAuto.app"
