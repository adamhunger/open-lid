#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p 'Open Lid.app/Contents/MacOS'
cp Source/Info.plist 'Open Lid.app/Contents/Info.plist'
xcrun swiftc Source/main.swift Source/Recovery.swift -o 'Open Lid.app/Contents/MacOS/OpenLid' -framework AppKit -framework CoreGraphics -framework Carbon
codesign --force --sign - 'Open Lid.app'
