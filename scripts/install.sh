#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
osascript -e 'quit app "SuiviAuto"' 2>/dev/null || true
CONFIGURATION=Release scripts/build.sh
APP="$HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli/Build/Products/Release/SuiviAuto.app"
rm -rf "/Applications/SuiviAuto.app"
cp -R "$APP" "/Applications/"
touch "/Applications/SuiviAuto.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/SuiviAuto.app" || true
echo "Installé : /Applications/SuiviAuto.app"
