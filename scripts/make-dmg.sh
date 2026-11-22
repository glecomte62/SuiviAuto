#!/bin/zsh
# Fabrique l'installeur à partager : dist/SuiviAuto-<version>.dmg
# (app Release universelle + raccourci Applications + notice LISEZ-MOI).
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIGURATION=Release scripts/build.sh
APP="$HOME/Library/Developer/Xcode/DerivedData/SuiviAuto-cli/Build/Products/Release/SuiviAuto.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp scripts/LISEZ-MOI.txt "$STAGE/LISEZ-MOI.txt"

mkdir -p dist
DMG="dist/SuiviAuto-$VERSION.dmg"
hdiutil create -volname "SuiviAuto $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "Installeur : $PWD/$DMG"
