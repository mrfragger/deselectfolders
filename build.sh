#!/bin/bash
set -e

APP_NAME="deselectfolders"
BUILD_DIR="$APP_NAME.app/Contents"
BUNDLE_ID="com.mrfragger.deselectfolders"

rm -rf "$APP_NAME.app"
mkdir -p "$BUILD_DIR/MacOS"
mkdir -p "$BUILD_DIR/Resources"

cp Info.plist "$BUILD_DIR/"

if [ -f icon.svg ]; then
    rm -rf icon.iconset
    mkdir icon.iconset
    for size in 16 32 64 128 256 512; do
        rsvg-convert -w $size -h $size icon.svg -o icon.iconset/icon_${size}x${size}.png
        rsvg-convert -w $((size*2)) -h $((size*2)) icon.svg -o icon.iconset/icon_${size}x${size}@2x.png
    done
    iconutil -c icns icon.iconset -o AppIcon.icns
    rm -rf icon.iconset
fi

if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "$BUILD_DIR/Resources/"
fi

swiftc -O main.swift -o "$BUILD_DIR/MacOS/$APP_NAME" \
    -framework Cocoa -framework Carbon -framework ApplicationServices

codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_NAME.app"

echo "Built and signed $APP_NAME.app"
