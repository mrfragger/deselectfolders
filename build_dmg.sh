#!/bin/bash
set -e

APP_NAME="deselectfolders"
VERSION="3.0"
DMG_NAME="${APP_NAME}-${VERSION}"
DMG_STAGING="dmg_staging"

# Make sure the app is built first
if [ ! -d "${APP_NAME}.app" ]; then
    echo "Error: ${APP_NAME}.app not found. Run ./build.sh first."
    exit 1
fi

rm -rf "$DMG_STAGING" "${DMG_NAME}.dmg"
mkdir "$DMG_STAGING"

cp -R "${APP_NAME}.app" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "${DMG_NAME}.dmg"

rm -rf "$DMG_STAGING"

echo "Created ${DMG_NAME}.dmg"
