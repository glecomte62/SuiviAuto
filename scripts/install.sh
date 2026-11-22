#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
osascript -e 'quit app "SuiviAuto"' 2>/dev/null || true
CONFIGURATION=Release scripts/build.sh
APP="$HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli/Build/Products/Release/SuiviAuto.app"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/SuiviAuto.app"
cp -R "$APP" "$HOME/Applications/"
echo "Installé : $HOME/Applications/SuiviAuto.app"
